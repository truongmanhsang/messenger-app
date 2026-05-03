import AppKit
import Foundation

enum DockBadge {
    private static let titleBadgePattern = #"\((\d+)\)"#

    @MainActor
    static func update(from title: String) {
        guard
            let regex = try? NSRegularExpression(pattern: titleBadgePattern),
            let match = regex.firstMatch(
                in: title,
                range: NSRange(title.startIndex..., in: title)
            ),
            let range = Range(match.range(at: 1), in: title)
        else {
            NSApplication.shared.dockTile.badgeLabel = nil
            return
        }

        NSApplication.shared.dockTile.badgeLabel = String(title[range])
    }
}
