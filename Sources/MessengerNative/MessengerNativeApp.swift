import SwiftUI
import UserNotifications
import WebKit

@main
struct MessengerNativeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("Messenger", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 400)
                .onAppear {
                    appDelegate.appState = appState
                    NSWindow.restoreSavedFrame()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Messenger") {
                Button("Reload") {
                    NotificationCenter.default.post(name: .reloadWebView, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Reload CSS") {
                    NotificationCenter.default.post(name: .reloadCustomCSS, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Debug Layout") {
                    NotificationCenter.default.post(name: .debugMessengerLayout, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Logout") {
                    NotificationCenter.default.post(name: .logoutWebView, object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Set Custom Domain") {
                    appState.showDomainSheet = true
                }

                Divider()

                Button("Test Notification") {
                    NotificationPresenter.show(
                        title: "Test Notification",
                        body: "Notification is working."
                    )
                }

                Button("Test Badge") {
                    NSApplication.shared.dockTile.badgeLabel = "99"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        NSApplication.shared.dockTile.badgeLabel = nil
                    }
                }

                Divider()

                Button("Show Data Folder") {
                    NSWorkspace.shared.open(FileManager.default.urls(
                        for: .applicationSupportDirectory,
                        in: .userDomainMask
                    )[0])
                }

                Divider()

                Button("Quit Messenger") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            NotificationPresenter.show(
                title: "Messenger",
                body: "Notifications are enabled."
            )
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}
