import Foundation
import UserNotifications

/// The permission side of the "Show notifications" toggle.
///
/// The toggle alone cannot say that macOS will deliver nothing: when the user
/// has turned notifications off for this app (or dismissed the first prompt
/// by killing the app — recorded as a denial, never asked again), the switch
/// sits ON while every alert vanishes. `UsageModel.notificationsDenied` is
/// derived here from the OS's answers and the settings window states it,
/// with a button to the only place that can change it.
enum NotificationAuth {
    /// From `requestAuthorization`'s callback. An error counts as denied:
    /// UNErrorDomain 1 "Notifications are not allowed for this application"
    /// arrives that way once the user has refused.
    static func denied(granted: Bool, error: Error?) -> Bool {
        !granted || error != nil
    }

    /// From `getNotificationSettings`: only an explicit refusal. `.notDetermined`
    /// means the prompt is still to come (`start()` / the toggle asks), and
    /// provisional / ephemeral grants do deliver something.
    static func denied(status: UNAuthorizationStatus) -> Bool {
        status == .denied
    }

    /// The stderr line for a refusal — the settings window may not be open.
    static func logLine(error: Error?) -> String {
        let why = error?.localizedDescription ?? "not granted"
        return "claude-usage-lens-gui: notifications \(why) — enable them in System Settings › Notifications"
    }

    /// Where macOS keeps the per-app notification switch.
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
}
