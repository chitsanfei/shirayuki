import Foundation
import CryptoKit

actor ImageLoader {
    static let shared = ImageLoader()
    
    private var memoryCache: [String: Data] = [:]
    private var ongoingTasks: [String: Task<Data, Error>] = [:]
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize = 0
    private var cacheOrder: [String] = []
    private let session: URLSession
    private let diskCacheDirectory: URL
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 90
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration)
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        diskCacheDirectory = cachesDirectory.appendingPathComponent("ShirayukiImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }
    
    func loadImage(from urlString: String) async throws -> Data? {
        try await loadImage(from: urlString, quality: AppImageQuality.stored)
    }

    func loadImage(from urlString: String, quality: AppImageQuality) async throws -> Data? {
        let resolvedURLString = await MainActor.run {
            AppProxyStore.shared.selectedRule.imageURL(for: urlString)
        }
        guard let url = URL(string: resolvedURLString) else { return nil }
        let cacheKey = "\(quality.rawValue)|\(resolvedURLString)"
        
        if let cached = memoryCache[cacheKey] {
            touchCache(for: cacheKey)
            return cached
        }

        if let diskData = try? Data(contentsOf: diskURL(for: cacheKey)) {
            setCache(key: cacheKey, data: diskData)
            return diskData
        }
        
        let task: Task<Data, Error>
        if let existingTask = ongoingTasks[cacheKey] {
            task = existingTask
        } else {
            task = Task(priority: .utility) { [session] in
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                request.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                request.setValue(quality.rawValue, forHTTPHeaderField: "image-quality")
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            ongoingTasks[cacheKey] = task
        }
        
        do {
            let data = try await task.value
            ongoingTasks.removeValue(forKey: cacheKey)
            if memoryCache[cacheKey] == nil {
                setCache(key: cacheKey, data: data)
                try? data.write(to: diskURL(for: cacheKey), options: .atomic)
            } else {
                touchCache(for: cacheKey)
            }
            return data
        } catch {
            ongoingTasks.removeValue(forKey: cacheKey)
            throw error
        }
    }
    
    private func setCache(key: String, data: Data) {
        while currentCacheSize + data.count > maxCacheSize && !cacheOrder.isEmpty {
            let oldest = cacheOrder.removeFirst()
            if let removedData = memoryCache.removeValue(forKey: oldest) {
                currentCacheSize -= removedData.count
            }
        }
        memoryCache[key] = data
        cacheOrder.append(key)
        currentCacheSize += data.count
    }
    
    private func touchCache(for key: String) {
        guard let index = cacheOrder.firstIndex(of: key) else { return }
        cacheOrder.remove(at: index)
        cacheOrder.append(key)
    }
    
    func preload(urls: [String]) {
        for urlString in Set(urls) {
            Task(priority: .utility) {
                _ = try? await loadImage(from: urlString)
            }
        }
    }
    
    func clear() {
        memoryCache.removeAll()
        cacheOrder.removeAll()
        currentCacheSize = 0
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    func cacheSize() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: diskCacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return files.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func removeCachedImage(from urlString: String, quality: AppImageQuality) {
        let cacheKey = "\(quality.rawValue)|\(urlString)"
        if let data = memoryCache.removeValue(forKey: cacheKey) {
            currentCacheSize -= data.count
        }
        cacheOrder.removeAll { $0 == cacheKey }
        try? FileManager.default.removeItem(at: diskURL(for: cacheKey))
    }

    private func diskURL(for cacheKey: String) -> URL {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return diskCacheDirectory.appendingPathComponent(digest).appendingPathExtension("data")
    }
}
