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
    func testAgentSendShowsUserMessageImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-agent-failing-provider")
        app.launch()

        app.buttons["agentFloatingButton"].tap()
        let input = app.textFields["agentInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        input.typeText("hello-live")
        app.buttons.matching(identifier: "agentSendButton").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["hello-live"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "agentState-transport_networkFailed")
                .firstMatch.waitForExistence(timeout: 3)
        )
        attachScreenshot(app, name: "Agent conversation with visible user message")
    }

    @MainActor
    func testAgentSettingsUseUnifiedDeepSeekProviderForm() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-agent-configured-key")
        app.launch()

        app.buttons["settingsButton"].tap()
        app.buttons["agentSettingsLink"].tap()

        let model = app.textFields["agentModelField"]
        let endpoint = app.textFields["agentBaseURLField"]
        XCTAssertTrue(model.waitForExistence(timeout: 3))
        XCTAssertEqual(model.value as? String, "deepseek-chat")
        XCTAssertEqual(
            endpoint.value as? String,
            "https://api.deepseek.com"
        )
        let apiKey = app.secureTextFields["agentAPIKeyField"]
        XCTAssertTrue(apiKey.waitForExistence(timeout: 2))
        XCTAssertTrue((apiKey.value as? String)?.contains("•") == true)
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentProviderFormatPicker").firstMatch.exists
        )
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentExecutionModePicker").firstMatch.exists
        )
        XCTAssertTrue(app.switches["agentRiskAuthorizationToggle"].exists)
        XCTAssertEqual(app.switches["agentRiskAuthorizationToggle"].value as? String, "1")
        attachScreenshot(app, name: "Agent sessions and risk authorization")
        app.swipeUp()
        let toolCallLimit = app.steppers["agentToolCallLimitStepper"]
        XCTAssertTrue(toolCallLimit.waitForExistence(timeout: 2))
        XCTAssertTrue((toolCallLimit.value as? String)?.contains("10") == true)
        XCTAssertTrue(app.switches["agentAutoCompactToggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentAutoCompactThresholdPicker")
                .firstMatch.waitForExistence(timeout: 2)
        )
        app.swipeUp()
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentSettingsApplyButton")
                .firstMatch.waitForExistence(timeout: 2)
        )
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentSettingsClearButton")
                .firstMatch.waitForExistence(timeout: 2)
        )
        let apply = app.buttons.matching(identifier: "agentSettingsApplyButton").firstMatch
        apply.tap()
        let resultAlert = app.alerts.firstMatch
        XCTAssertTrue(resultAlert.waitForExistence(timeout: 2))
        XCTAssertEqual(resultAlert.buttons.count, 1)
        attachScreenshot(app, name: "Agent settings applied result")
        app.buttons.matching(identifier: "agentSettingsNoticeDismissButton").firstMatch.tap()

        let clearToken = app.buttons.matching(identifier: "agentSettingsClearButton").firstMatch
        XCTAssertTrue(clearToken.waitForExistence(timeout: 2))
        clearToken.tap()
        let confirmClear = app.buttons.matching(identifier: "agentSettingsConfirm-clearToken").firstMatch
        XCTAssertTrue(confirmClear.waitForExistence(timeout: 2))
        confirmClear.tap()
        let clearedNotice = app.buttons.matching(
            identifier: "agentSettingsNoticeDismissButton"
        ).firstMatch
        XCTAssertTrue(clearedNotice.waitForExistence(timeout: 2))
        clearedNotice.tap()

        let reset = app.buttons.matching(identifier: "agentSettingsResetButton").firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 2))
        reset.tap()
        let confirmReset = app.buttons.matching(identifier: "agentSettingsConfirm-reset").firstMatch
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 2))
        confirmReset.tap()
        XCTAssertTrue(
            app.buttons.matching(identifier: "agentSettingsNoticeDismissButton")
                .firstMatch.waitForExistence(timeout: 2)
        )
        attachScreenshot(app, name: "Unified Agent provider settings")
    }

    @MainActor
    func testAgentSessionDeletionRequiresConfirmationAndShowsNotice() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["settingsButton"].tap()
        app.buttons["agentSettingsLink"].tap()

        let deleteSessions = app.buttons["agentSettingsDeleteAllSessionsButton"]
        XCTAssertTrue(deleteSessions.waitForExistence(timeout: 3))
        deleteSessions.tap()
        let confirm = app.buttons["agentSettingsConfirm-deleteSessions"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()
        XCTAssertTrue(
            app.buttons["agentSettingsNoticeDismissButton"].waitForExistence(timeout: 2)
        )
    }

    @MainActor
    func testOfflineCleanupRequiresConfirmationAndShowsNotice() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["settingsButton"].tap()
        let storage = app.buttons["storageSettingsLink"]
        for _ in 0..<5 where !storage.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(storage.waitForExistence(timeout: 3))
        XCTAssertTrue(storage.isHittable)
        storage.tap()

        let clearOffline = app.buttons["storageSettingsClearOfflineButton"]
        XCTAssertTrue(clearOffline.waitForExistence(timeout: 3))
        clearOffline.tap()
        let confirm = app.buttons["storageSettingsConfirm-clearOffline"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 2))
        confirm.tap()
        XCTAssertTrue(
            app.buttons["storageSettingsNoticeDismissButton"].waitForExistence(timeout: 2)
        )
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
    func testContentFilterAndAppearanceSettings() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["settingsButton"].tap()
        let contentFilter = app.buttons["contentFilterSettingsLink"]
        XCTAssertTrue(contentFilter.waitForExistence(timeout: 3))
        contentFilter.tap()

        app.buttons["addBlockedWordButton"].tap()
        let editor = app.alerts.textFields.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        editor.typeText("v005-ui-filter")
        app.buttons.matching(identifier: "saveBlockedWordButton").firstMatch.tap()
        let blockedWords = app.buttons["viewBlockedWordsButton"]
        XCTAssertTrue(blockedWords.waitForExistence(timeout: 2))
        blockedWords.tap()
        XCTAssertTrue(app.staticTexts["v005-ui-filter"].waitForExistence(timeout: 2))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let appearance = app.buttons["appearanceSettingsLink"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 2))
        appearance.tap()
        let opacity = app.sliders["agentButtonOpacitySlider"]
        XCTAssertTrue(opacity.waitForExistence(timeout: 2))
        opacity.adjust(toNormalizedSliderPosition: 0)
    }

    @MainActor
    func testComicActionsAreEqualWidthAcrossScreen() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-agent-surfaces")
        app.launch()

        app.buttons["comicActionsButton"].tap()
        XCTAssertTrue(app.otherElements["comicActionsFixture"].waitForExistence(timeout: 3))
        let buttons = [
            app.buttons.matching(identifier: "comicLikeActionButton").firstMatch,
            app.buttons.matching(identifier: "comicFavoriteActionButton").firstMatch,
            app.buttons.matching(identifier: "comicDownloadActionButton").firstMatch,
            app.buttons.matching(identifier: "comicReadActionButton").firstMatch
        ]
        XCTAssertTrue(buttons.allSatisfy(\.exists))
        let widths = buttons.map(\.frame.width)
        XCTAssertLessThan((widths.max() ?? 0) - (widths.min() ?? 0), 1)
        let leftMargin = buttons.first?.frame.minX ?? 0
        let rightMargin = app.frame.maxX - (buttons.last?.frame.maxX ?? 0)
        XCTAssertEqual(leftMargin, rightMargin, accuracy: 1)
        attachScreenshot(app, name: "Equal-width comic action buttons")
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
            let sheet = app.otherElements[sheetID]
            XCTAssertTrue(sheet.waitForExistence(timeout: 2))
            XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
            dismiss(sheet)
            XCTAssertTrue(trigger.waitForExistence(timeout: 2))
        }

        app.buttons["readerFixtureButton"].tap()
        XCTAssertTrue(app.otherElements["readerSurface"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)

        app.buttons["readerChapterButton"].tap()
        let chapterSheet = app.otherElements["readerChapterSheet"]
        XCTAssertTrue(chapterSheet.waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
        dismiss(chapterSheet)

        app.buttons["readerSettingsButton"].tap()
        XCTAssertTrue(app.otherElements["readerSettingsSheet"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifier: "agentFloatingButton").count, 1)
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func dismiss(_ sheet: XCUIElement) {
        let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.03))
        let end = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertFalse(sheet.waitForExistence(timeout: 2))
    }
}
