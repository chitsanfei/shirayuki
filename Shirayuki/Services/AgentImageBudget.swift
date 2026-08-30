import Foundation

#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Stable errors returned when current-page content cannot cross the provider boundary.
nonisolated enum AgentImageError: Error, Equatable, Sendable {
    case unavailable
    case tooLarge
    case rateLimited
    case unsupported
}
 
/// JPEG payload that can only be created after AgentImageBudget processing.
nonisolated struct AgentImagePayload: Equatable, Sendable {
    let jpegData: Data

    fileprivate init(processedJPEGData: Data) {
        self.jpegData = processedJPEGData
    }

    var dataURL: String {
        "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }
}

/// Enforces per-turn/provider image limits before an image reaches an LLM transport.
@MainActor
final class AgentImageBudget {
    static let shared = AgentImageBudget()

    nonisolated static let maxLongEdge = 2048
    nonisolated static let maxEncodedBytes = 10 * 1024 * 1024
    nonisolated static let maxImagesPerMinute = 3

    private var recentUploads: [String: [Date]] = [:]
    private var consumedTurns = Set<String>()

    private init() {}

    func prepare(_ data: Data, capability: AgentPageCapability, now: Date = Date()) throws -> AgentImagePayload {
        guard !consumedTurns.contains(capability.turnID) else {
            throw AgentImageError.rateLimited
        }

        let key = capability.providerKey
        recentUploads[key, default: []].removeAll { now.timeIntervalSince($0) >= 60 }
        guard recentUploads[key, default: []].count < Self.maxImagesPerMinute else {
            throw AgentImageError.rateLimited
        }

        let encoded = try downsampleAndEncode(data)
        guard encoded.count <= Self.maxEncodedBytes else {
            throw AgentImageError.tooLarge
        }
        consumedTurns.insert(capability.turnID)
        recentUploads[key, default: []].append(now)
        return AgentImagePayload(processedJPEGData: encoded)
    }

    func resetForTesting() {
        recentUploads.removeAll()
        consumedTurns.removeAll()
    }

    private func downsampleAndEncode(_ data: Data) throws -> Data {
        #if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AgentImageError.unavailable
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxLongEdge
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AgentImageError.unavailable
        }

        var quality = 0.82
        for _ in 0..<5 {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw AgentImageError.unsupported
            }
            CGImageDestinationAddImage(
                destination,
                image,
                [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination) else {
                throw AgentImageError.unsupported
            }
            let encoded = output as Data
            if encoded.count <= Self.maxEncodedBytes {
                return encoded
            }
            quality *= 0.7
        }
        throw AgentImageError.tooLarge
        #else
        throw AgentImageError.unsupported
        #endif
    }
}
