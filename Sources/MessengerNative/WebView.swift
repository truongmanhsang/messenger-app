import AppKit
import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = webView
        context.coordinator.installObservers()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?
        private var titleObservation: NSKeyValueObservation?
        private var observersInstalled = false

        func installObservers() {
            guard !observersInstalled else { return }
            observersInstalled = true

            titleObservation = webView?.observe(\.title, options: [.new]) { _, change in
                guard let title = change.newValue ?? nil else { return }
                Task { @MainActor in
                    DockBadge.update(from: title)
                }
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reload),
                name: .reloadWebView,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(reloadCSS),
                name: .reloadCustomCSS,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(loadCurrentDomain),
                name: .loadCurrentDomain,
                object: nil
            )
        }

        @objc private func reload() {
            webView?.reload()
        }

        @objc private func reloadCSS() {
            injectCustomCSS()
        }

        @objc private func loadCurrentDomain() {
            guard
                let domain = UserDefaults.standard.string(forKey: "customDomain"),
                let url = URL(string: domain)
            else { return }

            webView?.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectCustomCSS()
            injectNotificationHook()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .allow
            }

            if url.scheme == "http" || url.scheme == "https" {
                if !Self.shouldOpenInApp(url) {
                    NSWorkspace.shared.open(url)
                    return .cancel
                }
            }

            return .allow
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }

            if Self.shouldOpenInApp(url) {
                webView.load(URLRequest(url: url))
            } else {
                NSWorkspace.shared.open(url)
            }

            return nil
        }

        private func injectCustomCSS() {
            guard
                let cssURL = Bundle.module.url(forResource: "custom", withExtension: "css"),
                let css = try? String(contentsOf: cssURL)
            else { return }

            let escapedCSS = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")

            let script = """
            (function() {
                const existing = document.getElementById('native-custom-css');
                if (existing) existing.remove();
                const style = document.createElement('style');
                style.id = 'native-custom-css';
                style.textContent = `\(escapedCSS)`;
                document.documentElement.appendChild(style);
            })();
            """

            webView?.evaluateJavaScript(script)
        }

        private func injectNotificationHook() {
            let script = """
            (function() {
                if (window.__nativeNotificationHookInstalled) return;
                window.__nativeNotificationHookInstalled = true;
                const OriginalNotification = window.Notification;
                window.Notification = function(title, options) {
                    return new OriginalNotification(title, options);
                };
                Object.setPrototypeOf(window.Notification, OriginalNotification);
                Object.setPrototypeOf(window.Notification.prototype, OriginalNotification.prototype);
                window.Notification.permission = OriginalNotification.permission;
                window.Notification.requestPermission = OriginalNotification.requestPermission.bind(OriginalNotification);
            })();
            """

            webView?.evaluateJavaScript(script)
        }

        private static func shouldOpenInApp(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return true }

            return [
                "messenger.com",
                "facebook.com",
                "fbcdn.net",
                "fbsbx.com",
                "google.com"
            ].contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }
}
