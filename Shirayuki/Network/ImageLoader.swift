import Foundation

actor ImageLoader {
    static let shared = ImageLoader()
    
    private var memoryCache: [String: Data] = [:]
    private var ongoingTasks: [String: Task<Data, Error>] = [:]
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize = 0
    private var cacheOrder: [String] = []
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 90
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration)
    }
    
    func loadImage(from urlString: String) async throws -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        
        if let cached = memoryCache[urlString] {
            touchCache(for: urlString)
            return cached
        }
        
        let task: Task<Data, Error>
        if let existingTask = ongoingTasks[urlString] {
            task = existingTask
        } else {
            task = Task(priority: .utility) { [session] in
                var request = URLRequest(url: url)
                request.timeoutInterval = 20
                request.setValue("image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                return data
            }
            ongoingTasks[urlString] = task
        }
        
        do {
            let data = try await task.value
            ongoingTasks.removeValue(forKey: urlString)
            if memoryCache[urlString] == nil {
                setCache(key: urlString, data: data)
            } else {
                touchCache(for: urlString)
            }
            return data
        } catch {
            ongoingTasks.removeValue(forKey: urlString)
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
        let uniqueURLs = Array(Set(urls))
        for urlString in uniqueURLs {
            guard memoryCache[urlString] == nil, ongoingTasks[urlString] == nil else { continue }
            Task(priority: .utility) {
                _ = try? await loadImage(from: urlString)
            }
        }
    }
    
    func clear() {
        memoryCache.removeAll()
        cacheOrder.removeAll()
        currentCacheSize = 0
    }
}
