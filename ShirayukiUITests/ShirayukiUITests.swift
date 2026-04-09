import XCTest

final class ShirayukiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBottomBarAppearsForLoggedInState() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SKIP_WEB_LOAD", "UITEST_FORCE_LOGGED_IN"]
        app.launch()

        XCTAssertTrue(app.otherElements["bottomBar"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["searchFloatingButton"].exists)
    }

    @MainActor
    func testReaderModeShowsExitButtonAndHidesBottomBar() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SKIP_WEB_LOAD", "UITEST_FORCE_READER"]
        app.launch()

        XCTAssertTrue(app.buttons["exitReaderButton"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["bottomBar"].exists)
    }

    @MainActor
    func testStatusPlateAlwaysVisible() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UITEST_SKIP_WEB_LOAD"]
        app.launch()

        XCTAssertTrue(app.otherElements["statusPlate"].waitForExistence(timeout: 2))
    }
}
