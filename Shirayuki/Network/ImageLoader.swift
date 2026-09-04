import Foundation
import CryptoKit
import CoreGraphics
import ImageIO

/// Loads, rewrites, and caches comic images for the active network route.
actor ImageLoader {
    static let shared = ImageLoader()
    
    private var memoryCache: [String: Data] = [:]
    private var ongoingTasks: [String: Task<Data, Error>] = [:]
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize = 0
    private var cacheOrder: [String] = []
    private var decodedCache: [String: CGImage] = [:]
    private var decodedCacheOrder: [String] = []
    private var decodedCacheSources: [String: String] = [:]
    private var currentDecodedCacheSize = 0
    private let maxDecodedCacheSize = 160 * 1024 * 1024
    private var ongoingDecodeTasks: [String: Task<CGImage?, Never>] = [:]
    private var decodedCacheGeneration: UInt64 = 0
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
    
    /// Loads an image at the persisted quality setting.
    func loadImage(from urlString: String) async throws -> Data? {
        try await loadImage(from: urlString, quality: AppImageQuality.stored)
    }

    /// Resolves the active route, then loads an image from memory, disk, or network.
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
    /// Loads and decodes an online image away from the main actor.
    func loadDecodedImage(
        from urlString: String,
        quality: AppImageQuality,
        maximumPixelDimension: Int,
        priority: TaskPriority = .userInitiated
    ) async throws -> CGImage? {
        guard let data = try await loadImage(from: urlString, quality: quality) else { return nil }
        return await decodedImage(
            from: data,
            sourceKey: "\(quality.rawValue)|\(urlString)",
            maximumPixelDimension: maximumPixelDimension,
            priority: priority
        )
    }

    /// Returns an immediately drawable, size-bounded image and retains a decoded LRU entry.
    func decodedImage(
        from data: Data,
        sourceKey: String,
        maximumPixelDimension: Int,
        priority: TaskPriority = .userInitiated
    ) async -> CGImage? {
        let dimension = max(1, maximumPixelDimension)
        let cacheKey = "\(sourceKey)|pixels:\(dimension)"
        if let cached = decodedCache[cacheKey] {
            touchDecodedCache(for: cacheKey)
            return cached
        }

        let task: Task<CGImage?, Never>
        if let existingTask = ongoingDecodeTasks[cacheKey] {
            task = existingTask
        } else {
            task = Task.detached(priority: priority) {
                Self.decodeImage(data, maximumPixelDimension: dimension)
            }
            ongoingDecodeTasks[cacheKey] = task
        }

        let generation = decodedCacheGeneration
        let image = await task.value
        guard generation == decodedCacheGeneration else { return image }
        ongoingDecodeTasks.removeValue(forKey: cacheKey)
        if let image {
            setDecodedCache(key: cacheKey, sourceKey: sourceKey, image: image)
        }
        return image
    }

    nonisolated static func decodeImage(
        _ data: Data,
        maximumPixelDimension: Int
    ) -> CGImage? {
        guard maximumPixelDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maximumPixelDimension
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maximumPixelDimension
        let targetDimension = min(max(width, height), maximumPixelDimension)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func setDecodedCache(key: String, sourceKey: String, image: CGImage) {
        let cost = image.bytesPerRow * image.height
        guard cost <= maxDecodedCacheSize else { return }
        if let existing = decodedCache.removeValue(forKey: key) {
            currentDecodedCacheSize -= existing.bytesPerRow * existing.height
            decodedCacheOrder.removeAll { $0 == key }
        }
        while currentDecodedCacheSize + cost > maxDecodedCacheSize,
              let oldest = decodedCacheOrder.first {
            decodedCacheOrder.removeFirst()
            decodedCacheSources[oldest] = nil
            if let removed = decodedCache.removeValue(forKey: oldest) {
                currentDecodedCacheSize -= removed.bytesPerRow * removed.height
            }
        }
        decodedCache[key] = image
        decodedCacheOrder.append(key)
        decodedCacheSources[key] = sourceKey
        currentDecodedCacheSize += cost
    }

    private func touchDecodedCache(for key: String) {
        guard let index = decodedCacheOrder.firstIndex(of: key) else { return }
        decodedCacheOrder.remove(at: index)
        decodedCacheOrder.append(key)
    }

    private func removeDecodedCache(for sourceKey: String) {
        let keys = decodedCacheSources.compactMap { $0.value == sourceKey ? $0.key : nil }
        for key in keys {
            decodedCacheOrder.removeAll { $0 == key }
            decodedCacheSources[key] = nil
            if let removed = decodedCache.removeValue(forKey: key) {
                currentDecodedCacheSize -= removed.bytesPerRow * removed.height
            }
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
    
    /// Preloads and decodes nearby images with structured, cancellable tasks.
    func preload(urls: [String], maximumPixelDimension: Int) async {
        let quality = AppImageQuality.stored
        await withTaskGroup(of: Void.self) { group in
            for urlString in Set(urls) {
                group.addTask(priority: .utility) {
                    _ = try? await self.loadDecodedImage(
                        from: urlString,
                        quality: quality,
                        maximumPixelDimension: maximumPixelDimension,
                        priority: .utility
                    )
                }
            }
        }
    }
    
    /// Removes all in-memory and on-disk image cache entries.
    func clear() {
        memoryCache.removeAll()
        cacheOrder.removeAll()
        currentCacheSize = 0
        decodedCache.removeAll()
        decodedCacheOrder.removeAll()
        decodedCacheSources.removeAll()
        currentDecodedCacheSize = 0
        decodedCacheGeneration &+= 1
        ongoingDecodeTasks.values.forEach { $0.cancel() }
        ongoingDecodeTasks.removeAll()
        try? FileManager.default.removeItem(at: diskCacheDirectory)
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    /// Returns the total number of bytes currently stored on disk.
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

    /// Evicts one quality-specific image from encoded, decoded, and disk caches.
    func removeCachedImage(from urlString: String, quality: AppImageQuality) {
        let cacheKey = "\(quality.rawValue)|\(urlString)"
        if let data = memoryCache.removeValue(forKey: cacheKey) {
            currentCacheSize -= data.count
        }
        cacheOrder.removeAll { $0 == cacheKey }
        removeDecodedCache(for: cacheKey)
        try? FileManager.default.removeItem(at: diskURL(for: cacheKey))
    }

    private func diskURL(for cacheKey: String) -> URL {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return diskCacheDirectory.appendingPathComponent(digest).appendingPathExtension("data")
    }
}
