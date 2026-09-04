import CoreGraphics
import ImageIO
import XCTest
@testable import Shirayuki

final class AppAppearanceV005Tests: XCTestCase {
    @MainActor
    func testDefaultsClampAndEffectiveMotionMatrix() async throws {
        let suite = "AppearanceV005.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppAppearanceStore(defaults: defaults)

        XCTAssertEqual(store.themeMode, .system)
        XCTAssertEqual(store.animationMode, .standard)
        XCTAssertEqual(store.buttonStyle, .glass)
        XCTAssertEqual(store.buttonOpacity, 1)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .standard)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .reduced)

        store.setAnimationMode(.reduced)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .reduced)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .reduced)
        store.setAnimationMode(.off)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: false), .off)
        XCTAssertEqual(store.effectiveMode(systemReduceMotion: true), .off)

        store.setButtonOpacity(0.41)
        XCTAssertEqual(store.buttonOpacity, 0.40)
        store.setButtonOpacity(1.4)
        XCTAssertEqual(store.buttonOpacity, 1.00)
    }

    func testImageQualityUsesHighDefaultAndPreservesExplicitChoice() throws {
        let suite = "ImageQuality.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(AppImageQuality.stored(in: defaults), .high)
        defaults.set(AppImageQuality.original.rawValue, forKey: AppImageQuality.storageKey)
        XCTAssertEqual(AppImageQuality.stored(in: defaults), .original)
    }

    func testImageDecoderDownsamplesAndPreservesAspectRatio() throws {
        let width = 400
        let height = 200
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(
            CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )
        let sourceImage = try XCTUnwrap(context.makeImage())
        let encodedData = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(encodedData, "public.png" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, sourceImage, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let data = Data(referencing: encodedData)

        let decoded = try XCTUnwrap(
            ImageLoader.decodeImage(data, maximumPixelDimension: 100)
        )
        XCTAssertEqual(decoded.width, 100)
        XCTAssertEqual(decoded.height, 50)
        XCTAssertNil(ImageLoader.decodeImage(data, maximumPixelDimension: 0))
    }
}
