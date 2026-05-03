import AppKit
import Foundation
import UserNotifications

enum NotificationPresenter {
    static func show(title: String, body: String) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                deliver(title: title, body: body)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        deliver(title: title, body: body)
                    } else {
                        showFailure(message(for: error) ?? "Notifications were not allowed.")
                    }
                }
            case .denied:
                showFailure("Notifications are disabled for Messenger. Enable them in System Settings > Notifications.")
            @unknown default:
                showFailure("Notification authorization is unavailable.")
            }
        }
    }

    private static func deliver(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                showFailure(message(for: error) ?? error.localizedDescription)
            }
        }
    }

    private static func showFailure(_ message: String) {
        Task { @MainActor in
            let alert = NSAlert()
            alert.messageText = "Notification Failed"
            alert.informativeText = message
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")

            if alert.runModal() == .alertFirstButtonReturn {
                openNotificationSettings()
            }
        }
    }

    private static func message(for error: Error?) -> String? {
        guard let nsError = error as NSError? else { return nil }

        if nsError.domain == UNErrorDomain && nsError.code == 1 {
            return "Notifications are not allowed for this app. Enable them in System Settings > Notifications, then try again."
        }

        return nsError.localizedDescription
    }

    private static func openNotificationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }

            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
