import UserNotifications
import XCTest
@testable import ClaudeUsageLens

/// The "Show notifications" toggle's permission rules. The OS calls themselves
/// need a running app and are not exercised here.
final class NotificationAuthTests: XCTestCase {
    private let notAllowed = NSError(domain: "UNErrorDomain", code: 1,
                                     userInfo: [NSLocalizedDescriptionKey: "Notifications are not allowed for this application"])

    // requestAuthorization's callback: only a clean grant is not a denial. A
    // refusal arrives as granted=false, or as UNErrorDomain 1 once recorded.
    func testRequestResult() {
        XCTAssertFalse(NotificationAuth.denied(granted: true, error: nil))
        XCTAssertTrue(NotificationAuth.denied(granted: false, error: nil))
        XCTAssertTrue(NotificationAuth.denied(granted: false, error: notAllowed))
        XCTAssertTrue(NotificationAuth.denied(granted: true, error: notAllowed))
    }

    // getNotificationSettings: `.notDetermined` is "not asked yet", never a
    // denial — the prompt is still to come. Provisional grants deliver.
    func testStatusMapping() {
        XCTAssertTrue(NotificationAuth.denied(status: .denied))
        XCTAssertFalse(NotificationAuth.denied(status: .authorized))
        XCTAssertFalse(NotificationAuth.denied(status: .notDetermined))
        XCTAssertFalse(NotificationAuth.denied(status: .provisional))
    }

    // The stderr line names the app, the reason, and where to fix it.
    func testLogLine() {
        let plain = NotificationAuth.logLine(error: nil)
        XCTAssertTrue(plain.hasPrefix("claude-usage-lens-gui:") && plain.contains("not granted") && plain.contains("System Settings"))
        XCTAssertTrue(NotificationAuth.logLine(error: notAllowed).contains("not allowed for this application"))
    }

    func testSettingsURLTargetsNotificationsPane() {
        XCTAssertEqual(NotificationAuth.settingsURL.scheme, "x-apple.systempreferences")
        XCTAssertTrue(NotificationAuth.settingsURL.absoluteString.contains("Notifications-Settings"))
    }
}
