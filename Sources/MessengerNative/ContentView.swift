import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        WebView(url: appState.activeURL)
            .sheet(isPresented: $appState.showDomainSheet) {
                DomainSheet()
                    .environmentObject(appState)
            }
    }
}

private struct DomainSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Custom Domain")
                .font(.headline)

            TextField("https://www.messenger.com", text: $draft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)
                .onSubmit(save)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save & Reload") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear {
            draft = appState.domainText
        }
    }

    private func save() {
        appState.saveDomain(draft)
        NotificationCenter.default.post(name: .loadCurrentDomain, object: nil)
        dismiss()
    }
}
