import UIKit
import XCTest

/// Captures the title screen so CI can publish it.
///
/// The image is attached to the test result and, when running in a
/// simulator, also written to ~/doctorsworld-screenshots on the Mac that
/// hosts the simulator, where CI picks it up.
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureTitleScreen() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Doctors World"].waitForExistence(timeout: 15))
        sleep(1)

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "Title screen"
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let hostHome = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let folder = URL(fileURLWithPath: hostHome).appendingPathComponent("doctorsworld-screenshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: folder.appendingPathComponent("\(device)-title-screen.png"))
    }
}
