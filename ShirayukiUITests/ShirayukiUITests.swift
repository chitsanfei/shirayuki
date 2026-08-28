import XCTest

/// Exercises the deterministic unauthenticated Agent and Settings surfaces.
final class ShirayukiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAgentButtonOpensConversationOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let button = app.buttons["agentFloatingButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.otherElements["agentConversationPanel"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSettingsSuppressesAgentButton() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["agentFloatingButton"].waitForExistence(timeout: 5))
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 2))
        settings.tap()
        XCTAssertTrue(app.otherElements["settingsSheet"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["agentFloatingButton"].exists)
    }

    @MainActor
    func testDebugAgentSurfaceFixturePresentsOneSurfaceAtATime() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-agent-surfaces")
        app.launch()

        XCTAssertTrue(app.buttons["agentFloatingButton"].waitForExistence(timeout: 5))
        for (buttonID, sheetID) in [
            ("searchFiltersButton", "searchFiltersSheet"),
            ("downloadOptionsButton", "downloadOptionsSheet"),
            ("offlineDownloadButton", "offlineDownloadSheet")
        ] {
            let trigger = app.buttons[buttonID]
            XCTAssertTrue(trigger.waitForExistence(timeout: 2))
            trigger.tap()
            XCTAssertTrue(app.otherElements[sheetID].waitForExistence(timeout: 2))
            XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
            app.swipeDown()
            XCTAssertTrue(trigger.waitForExistence(timeout: 2))
        }

        app.buttons["readerFixtureButton"].tap()
        XCTAssertTrue(app.otherElements["readerSurface"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)

        app.buttons["readerChapterButton"].tap()
        XCTAssertTrue(app.otherElements["readerChapterSheet"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
        app.swipeDown()

        app.buttons["readerSettingsButton"].tap()
        XCTAssertTrue(app.otherElements["readerSettingsSheet"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
    }
}
