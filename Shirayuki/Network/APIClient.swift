import Foundation
import CryptoKit

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(Int, String)
    case unauthorized
    case emptyData
    case encodingError(String)
    case decodingError(String)
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.unauthorized, .unauthorized): return true
        case (.emptyData, .emptyData): return true
        case let (.encodingError(l), .encodingError(r)): return l == r
        case let (.serverError(l1, l2), .serverError(r1, r2)): return l1 == r1 && l2 == r2
        case let (.decodingError(l), .decodingError(r)): return l == r
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return AppLocalization.text("api.invalidURL")
        case .networkError(let error):
            return AppLocalization.text("api.networkError", error.localizedDescription)
        case .invalidResponse:
            return AppLocalization.text("api.invalidResponse")
        case .serverError(let code, let msg):
            return AppLocalization.text("api.serverError", code, msg)
        case .unauthorized:
            return AppLocalization.text("api.unauthorized")
        case .emptyData:
            return AppLocalization.text("api.emptyData")
        case .encodingError(let msg):
            return AppLocalization.text("api.encodingError", msg)
        case .decodingError(let msg):
            return AppLocalization.text("api.decodingError", msg)
        }
    }
}

extension APIError: LocalizedError {}

actor APIClient {
    static let shared = APIClient()
    
    private let apiKey = "C69BAF41DA5ABD1FFEDC6D2FEA56B"
    private let secretKey = "~d}$Q7$eIni=V)9\\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn"
    private let nonce = "4ce7a7aa759b40f794d189a88b84aba8"
    
    private var baseURL: String = "https://picaapi.go2778.com/"
    private var token: String = ""
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)
    }
    
    func setBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    func setToken(_ token: String) {
        self.token = token
    }
    
    func clearToken() {
        self.token = ""
    }
    
    private var defaultHeaders: [String: String] {
        [
            "accept": "application/vnd.picacomic.com.v1+json",
            "User-Agent": "okhttp/3.8.1",
            "Content-Type": "application/json; charset=UTF-8",
            "api-key": apiKey,
            "app-build-version": "45",
            "app-platform": "android",
            "app-uuid": "defaultUuid",
            "app-version": "2.2.1.3.3.4",
            "nonce": nonce,
            "app-channel": "1",
        ]
    }
    
    private func getSignature(url: String, timestamp: String, nonce: String, method: HTTPMethod) -> String {
        let key = (url + timestamp + nonce + method.rawValue + apiKey).lowercased()
        let keyData = Data(key.utf8)
        let secretData = Data(secretKey.utf8)
        let signature = HMAC<SHA256>.authenticationCode(for: keyData, using: SymmetricKey(data: secretData))
        return signature.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func getHeaders(url: String, method: HTTPMethod) -> [String: String] {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = getSignature(url: url, timestamp: timestamp, nonce: nonce, method: method)
        var headers = defaultHeaders
        headers["time"] = timestamp
        headers["signature"] = signature
        headers["authorization"] = token
        headers["image-quality"] = "original"
        return headers
    }
    
    func request<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        let maxRetries = 3
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            try Task.checkCancellation()
            do {
                return try await performRequest(method, path: path, query: query, body: body)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as APIError {
                lastError = error
                if case .serverError(let code, _) = error, code >= 500 && code < 600 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
                throw error
            } catch let error as URLError {
                if error.code == .cancelled {
                    throw CancellationError()
                }
                lastError = APIError.networkError(error)
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
            } catch {
                if error is CancellationError {
                    throw CancellationError()
                }
                lastError = APIError.networkError(error)
                if attempt < maxRetries - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
            }
        }
        throw lastError ?? APIError.networkError(NSError(domain: "", code: -1))
    }
    
    private func performRequest<T: Decodable & Sendable>(
        _ method: HTTPMethod,
        path: String,
        query: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> T {
        try Task.checkCancellation()

        guard let baseURL = URL(string: baseURL),
              let initialURL = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        let sortedQueryItems = (query ?? [:])
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }

        guard var components = URLComponents(url: initialURL, resolvingAgainstBaseURL: true) else {
            throw APIError.invalidURL
        }
        if !sortedQueryItems.isEmpty {
            components.queryItems = sortedQueryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let signaturePath: String = {
            let queryString = components.percentEncodedQuery ?? ""
            if queryString.isEmpty {
                return path
            }
            if path.contains("?") {
                return path
            }
            return "\(path)?\(queryString)"
        }()
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 20
        
        let headers = getHeaders(url: signaturePath, method: method)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body, method != .get {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw APIError.encodingError(error.localizedDescription)
            }
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }
            throw APIError.networkError(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.networkError(error)
        }
        
        try Task.checkCancellation()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                throw APIError.serverError(400, message)
            }
            throw APIError.serverError(400, AppLocalization.text("api.badRequest"))
        case 401:
            token = ""
            Task { @MainActor in
                NotificationCenter.default.post(name: .apiClientDidReceiveUnauthorized, object: nil)
            }
            throw APIError.unauthorized
        default:
            throw APIError.serverError(httpResponse.statusCode, "HTTP \(httpResponse.statusCode)")
        }
        
        guard !data.isEmpty else {
            throw APIError.emptyData
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

extension Notification.Name {
    static let apiClientDidReceiveUnauthorized = Notification.Name("apiClientDidReceiveUnauthorized")
}
