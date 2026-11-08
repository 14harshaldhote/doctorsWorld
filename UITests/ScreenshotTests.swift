import UIKit
import XCTest

/// Captures the title, a shift in progress and the results so CI can
/// publish them.
///
/// Each image is attached to the test result and, when running in a
/// simulator, also written to ~/doctorsworld-screenshots on the Mac that
/// hosts the simulator, where CI picks it up.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-freshProfile", "YES", "-autoplay", "YES", "-seed", "11",
            "-shiftSeconds", "45", "-arrivalSeconds", "5", "-timeScale", "1.5"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["Doctors World"].waitForExistence(timeout: 15))
        sleep(1)
        try capture("title-screen")

        app.buttons["startShiftButton"].tap()
        XCTAssertTrue(app.staticTexts["shiftClock"].waitForExistence(timeout: 10))
        sleep(14)
        try capture("shift")

        XCTAssertTrue(app.staticTexts["resultsTitle"].waitForExistence(timeout: 90))
        sleep(3)
        try capture("results")
    }

    @MainActor
    private func capture(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let folder = URL(fileURLWithPath: hostHome).appendingPathComponent("doctorsworld-screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: folder.appendingPathComponent("\(device)-\(name).png"))
    }
}
