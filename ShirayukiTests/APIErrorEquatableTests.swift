import Foundation
import XCTest
@testable import Shirayuki

final class APIErrorEquatableTests: XCTestCase {
    func testNetworkErrorsWithSameNSErrorAreEqual() {
        let left = URLError(.notConnectedToInternet)
        let right = URLError(.notConnectedToInternet)
        XCTAssertEqual(APIError.networkError(left), APIError.networkError(right))
    }

    func testNetworkErrorsWithDifferentCodesAreNotEqual() {
        let left = URLError(.notConnectedToInternet)
        let right = URLError(.timedOut)
        XCTAssertNotEqual(APIError.networkError(left), APIError.networkError(right))
    }

    func testServerErrorEquality() {
        XCTAssertEqual(APIError.serverError(500, "boom"), APIError.serverError(500, "boom"))
        XCTAssertNotEqual(APIError.serverError(500, "boom"), APIError.serverError(502, "boom"))
        XCTAssertNotEqual(APIError.serverError(500, "boom"), APIError.serverError(500, "other"))
    }

    func testDistinctCasesAreNotEqual() {
        XCTAssertNotEqual(APIError.unauthorized, APIError.invalidURL)
        XCTAssertNotEqual(APIError.emptyData, APIError.invalidResponse)
    }

    func testEncodingDecodingErrorsCompareByMessage() {
        XCTAssertEqual(APIError.encodingError("a"), APIError.encodingError("a"))
        XCTAssertNotEqual(APIError.encodingError("a"), APIError.encodingError("b"))
        XCTAssertEqual(APIError.decodingError("x"), APIError.decodingError("x"))
    }
}