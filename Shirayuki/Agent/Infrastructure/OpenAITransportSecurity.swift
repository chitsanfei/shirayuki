import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct OpenAITransportError: Error, Equatable, Sendable {
    enum Code: String, Sendable {
        case configurationRequired
        case invalidEndpoint
        case redirectRejected
        case invalidImage
        case visionUnsupported
        case invalidResponse
        case unauthorized
        case serverError
        case decodingFailed
        case networkFailed
    }

    let code: Code
}

nonisolated struct LLMOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int

    init?(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !scheme.isEmpty,
              !host.isEmpty else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = url.port ?? (scheme == "https" ? 443 : 80)
    }

    func contains(_ url: URL) -> Bool {
        guard let other = LLMOrigin(url) else { return false }
        return self == other
    }
}

/// Prevents credentials and content crossing origins or downgrading HTTPS.
final class OpenAIOriginPinningDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let origin: LLMOrigin

    init(origin: LLMOrigin) {
        self.origin = origin
    }

    static func allowsRedirect(from source: URL, to destination: URL) -> Bool {
        guard let sourceOrigin = LLMOrigin(source),
              let destinationOrigin = LLMOrigin(destination) else { return false }
        return sourceOrigin == destinationOrigin && destinationOrigin.scheme == "https"
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @Sendable @escaping (URLRequest?) -> Void
    ) {
        guard let currentURL = task.currentRequest?.url,
              let destinationURL = request.url,
              origin.contains(currentURL),
              origin.contains(destinationURL),
              Self.allowsRedirect(from: currentURL, to: destinationURL) else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
