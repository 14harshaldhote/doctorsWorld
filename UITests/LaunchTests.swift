import XCTest

/// Smoke test: the app launches and shows its title screen.
final class LaunchTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testTitleScreenAppears() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshProfile", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Doctors World"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["startShiftButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["coreVersionLabel"].exists)
    }
}
