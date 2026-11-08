import XCTest

/// Smoke test: the app launches and shows its title screen.
final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTitleScreenAppears() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Pulse Ward"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["startShiftButton"].exists)
        XCTAssertTrue(app.staticTexts["coreVersionLabel"].exists)
    }
}
