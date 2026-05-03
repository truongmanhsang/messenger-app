import AppKit

extension NSWindow {
    private static let frameAutosaveName = "MessengerNativeMainWindow"

    static func restoreSavedFrame() {
        guard let window = NSApplication.shared.windows.first else { return }

        window.setFrameAutosaveName(frameAutosaveName)
        if !window.setFrameUsingName(frameAutosaveName) {
            window.setFrame(
                NSRect(x: 0, y: 0, width: 890, height: 790),
                display: true
            )
            window.center()
        }

        window.title = "Messenger"
    }
}
