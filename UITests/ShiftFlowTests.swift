import XCTest

/// End-to-end tests: start a shift, play it, and land on the results.
final class ShiftFlowTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The computer plays a short, busy shift from start to results, and
    /// the career card then shows on the title screen.
    @MainActor
    func testAutoPlayedShiftEndsWithResults() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-freshProfile", "YES", "-autoplay", "YES", "-seed", "7", "-shiftSeconds", "24", "-arrivalSeconds", "6"
        ]
        app.launch()

        let start = app.buttons["startShiftButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        XCTAssertTrue(app.staticTexts["shiftClock"].waitForExistence(timeout: 10))

        XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 90))
        let earned = app.staticTexts["resultsXP"]
        XCTAssertTrue(earned.exists)
        XCTAssertFalse(earned.label.hasPrefix("0 "), "the shift should earn some XP, got: \(earned.label)")

        app.buttons["backToTitleButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["careerCard"].waitForExistence(timeout: 10))
    }

    /// A player can triage, examine and open the casebook with plain taps,
    /// then walk off the floor from the pause menu.
    @MainActor
    func testTriageExamineAndEndShiftByTapping() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshProfile", "YES", "-seed", "5", "-shiftSeconds", "600"]
        app.launch()

        app.buttons["startShiftButton"].tap()
        let waiting = app.buttons["waiting-1"]
        XCTAssertTrue(waiting.waitForExistence(timeout: 10))
        waiting.tap()
        app.buttons["assignBed1"].tap()

        let examine = app.buttons["examineButton"]
        XCTAssertTrue(examine.waitForExistence(timeout: 5))
        examine.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: examine)
        wait(for: [gone], timeout: 5)

        app.buttons["diagnoseButton"].tap()
        XCTAssertTrue(app.buttons["diagnose-dehydration"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["pauseButton"].tap()
        let end = app.buttons["endShiftButton"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["nextShiftButton"].exists)
    }
}
