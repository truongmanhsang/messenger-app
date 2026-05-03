import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var showDomainSheet = false
    @Published var domainText: String
    @Published var activeURL: URL

    private let domainKey = "customDomain"
    private let defaultDomain = "https://facebook.com/messages"

    init() {
        let savedDomain = UserDefaults.standard.string(forKey: domainKey) ?? defaultDomain
        domainText = savedDomain
        activeURL = URL(string: savedDomain) ?? URL(string: defaultDomain)!
    }

    func saveDomain(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }

        guard let url = URL(string: value) else { return }

        domainText = value
        activeURL = url
        UserDefaults.standard.set(value, forKey: domainKey)
    }
}
