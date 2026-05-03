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
                selector: #selector(debugLayout),
                name: .debugMessengerLayout,
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
            injectMessengerShellFix()
        }

        @objc private func debugLayout() {
            debugMessengerLayout()
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
            injectMessengerShellFix()
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

        private func injectMessengerShellFix() {
            let script = """
            (function() {
                const headerHeights = new Set([44, 48, 50, 52, 56, 60, 64]);
                const isHeaderOffset = value => headerHeights.has(Math.round(parseFloat(value) || 0));
                const shellMarker = 'native-messenger-shell';

                function forceStyle(element, property, value) {
                    element.style.setProperty(property, value, 'important');
                }

                function expandHeaderSizedCalcs(root) {
                    const calcPattern = /calc\\((100(?:vh|%)?)\\s*-\\s*(44|48|50|52|56|60|64)px\\)/;
                    const properties = ['height', 'minHeight', 'maxHeight', 'flexBasis'];

                    [root, ...root.querySelectorAll('*')].forEach(element => {
                        properties.forEach(property => {
                            const value = element.style[property];

                            if (!calcPattern.test(value)) return;

                            element.style.setProperty(
                                property.replace(/[A-Z]/g, match => '-' + match.toLowerCase()),
                                value.replace(calcPattern, 'calc($1 - 0px)'),
                                'important'
                            );
                        });
                    });
                }

                function fillHeaderSizedFooterGaps() {
                    const roots = [
                        document.body,
                        ...document.querySelectorAll('[role="main"]')
                    ];

                    roots.forEach(root => Array.from(root.querySelectorAll('*')).forEach(element => {
                        const rect = element.getBoundingClientRect();
                        const footerGap = Math.round(window.innerHeight - rect.bottom);
                        const isTopAligned = rect.top <= 2;
                        const isMainPaneGap = root.getAttribute('role') === 'main'
                            && footerGap >= 80
                            && footerGap <= 96
                            && isTopAligned;
                        const isHeaderPaneGap = headerHeights.has(footerGap) && isTopAligned;

                        if (rect.width < 300) return;
                        if (rect.height < window.innerHeight * 0.3) return;
                        if (!isHeaderPaneGap && !isMainPaneGap) return;

                        const height = Math.ceil(rect.height + footerGap) + 'px';

                        forceStyle(element, 'height', height);
                        forceStyle(element, 'min-height', height);
                        forceStyle(element, 'max-height', 'none');
                        forceStyle(element, 'padding-bottom', '0px');
                        forceStyle(element, 'margin-bottom', '0px');
                    }));
                }

                function collapseMessengerHeader() {
                    forceStyle(document.documentElement, 'height', '100%');
                    forceStyle(document.body, 'height', '100%');
                    forceStyle(document.body, 'padding-top', '0px');
                    forceStyle(document.body, 'margin-top', '0px');

                    document.querySelectorAll('[role="banner"]').forEach(header => {
                        forceStyle(header, 'display', 'none');
                        forceStyle(header, 'height', '0px');
                        forceStyle(header, 'min-height', '0px');
                        forceStyle(header, 'max-height', '0px');
                        forceStyle(header, 'overflow', 'hidden');
                    });

                    const candidates = Array.from(document.querySelectorAll('body *'))
                        .map(element => {
                            const style = getComputedStyle(element);
                            const rect = element.getBoundingClientRect();
                            const isPageSized = rect.width >= window.innerWidth * 0.75
                                && rect.height >= window.innerHeight * 0.5;
                            const hasHeaderTop = isHeaderOffset(style.top)
                                || isHeaderOffset(style.marginTop)
                                || isHeaderOffset(style.paddingTop)
                                || (rect.top >= 44 && rect.top <= 64 && isPageSized);

                            return { element, style, rect, isPageSized, hasHeaderTop };
                        })
                        .filter(candidate => candidate.isPageSized && candidate.hasHeaderTop)
                        .sort((a, b) => {
                            const areaA = a.rect.width * a.rect.height;
                            const areaB = b.rect.width * b.rect.height;
                            return areaB - areaA;
                        });

                    const shell = candidates[0]?.element || document.querySelector('[data-' + shellMarker + '="true"]');

                    document.querySelectorAll('[data-' + shellMarker + '="true"]').forEach(element => {
                        if (element !== shell) {
                            element.removeAttribute('data-' + shellMarker);
                        }
                    });

                    if (shell) {
                        shell.setAttribute('data-' + shellMarker, 'true');
                    }

                    document.querySelectorAll('[data-' + shellMarker + '="true"]').forEach(element => {
                        const style = getComputedStyle(element);
                        forceStyle(element, 'top', '0px');
                        forceStyle(element, 'bottom', '0px');
                        forceStyle(element, 'margin-top', '0px');
                        forceStyle(element, 'padding-top', '0px');
                        forceStyle(element, 'min-height', '0px');
                        forceStyle(element, 'max-height', 'none');

                        if (style.position === 'fixed' || style.position === 'absolute' || style.height.includes('calc')) {
                            forceStyle(element, 'height', 'calc(100vh - 0px)');
                        }

                        if (style.position === 'static') {
                            forceStyle(element, 'position', 'relative');
                        }
                    });

                    expandHeaderSizedCalcs(document.body);
                    fillHeaderSizedFooterGaps();
                }

                if (window.__nativeMessengerShellFixInstalled) {
                    collapseMessengerHeader();
                    return;
                }

                window.__nativeMessengerShellFixInstalled = true;
                let scheduled = false;
                const scheduleCollapse = () => {
                    if (scheduled) return;
                    scheduled = true;
                    requestAnimationFrame(() => {
                        scheduled = false;
                        collapseMessengerHeader();
                    });
                };

                new MutationObserver(scheduleCollapse).observe(document.documentElement, {
                    subtree: true,
                    childList: true,
                    attributes: true,
                    attributeFilter: ['class', 'style', 'role', 'aria-label']
                });

                collapseMessengerHeader();
                window.setInterval(collapseMessengerHeader, 1000);
            })();
            """

            webView?.evaluateJavaScript(script)
        }

        private func debugMessengerLayout() {
            let script = """
            (function() {
                function describe(element) {
                    if (!element) return 'null';

                    const rect = element.getBoundingClientRect();
                    const style = getComputedStyle(element);
                    const attrs = [
                        element.tagName.toLowerCase(),
                        element.id ? '#' + element.id : '',
                        element.getAttribute('role') ? '[role="' + element.getAttribute('role') + '"]' : '',
                        element.getAttribute('aria-label') ? '[aria-label="' + element.getAttribute('aria-label') + '"]' : '',
                        element.getAttribute('data-native-messenger-shell') ? '[data-native-messenger-shell="' + element.getAttribute('data-native-messenger-shell') + '"]' : ''
                    ].filter(Boolean).join('');

                    return [
                        attrs,
                        'rect=' + [rect.left, rect.top, rect.width, rect.height, rect.bottom].map(value => Math.round(value)).join(','),
                        'gapBottom=' + Math.round(window.innerHeight - rect.bottom),
                        'pos=' + style.position,
                        'display=' + style.display,
                        'overflow=' + style.overflow + '/' + style.overflowY,
                        'top=' + style.top,
                        'bottom=' + style.bottom,
                        'height=' + style.height,
                        'minHeight=' + style.minHeight,
                        'maxHeight=' + style.maxHeight,
                        'padding=' + style.paddingTop + '/' + style.paddingBottom,
                        'margin=' + style.marginTop + '/' + style.marginBottom,
                        'inlineStyle="' + (element.getAttribute('style') || '').slice(0, 220) + '"',
                        'class="' + (element.className || '').toString().slice(0, 180) + '"'
                    ].join(' | ');
                }

                function elementsAt(x, y) {
                    return document.elementsFromPoint(x, y).slice(0, 10).map(describe);
                }

                const main = document.querySelector('[role="main"]');
                const textbox = Array.from(document.querySelectorAll('[role="textbox"], textarea'))
                    .map(element => ({ element, rect: element.getBoundingClientRect() }))
                    .filter(item => item.rect.width > 120)
                    .sort((a, b) => b.rect.top - a.rect.top)[0]?.element || null;
                const mainRect = main ? main.getBoundingClientRect() : null;
                const textRect = textbox ? textbox.getBoundingClientRect() : null;
                const chatX = mainRect ? Math.round(mainRect.left + mainRect.width / 2) : Math.round(window.innerWidth * 0.75);
                const footerY = Math.max(0, window.innerHeight - 24);
                const aboveFooterY = Math.max(0, window.innerHeight - 72);
                const textboxY = textRect ? Math.round(textRect.top + textRect.height / 2) : aboveFooterY;

                const candidates = Array.from(document.querySelectorAll('body *'))
                    .map(element => ({ element, rect: element.getBoundingClientRect() }))
                    .filter(item => item.rect.width >= 200 && item.rect.height >= 80 && item.rect.top < window.innerHeight && item.rect.bottom > 0)
                    .sort((a, b) => Math.abs(window.innerHeight - a.rect.bottom) - Math.abs(window.innerHeight - b.rect.bottom))
                    .slice(0, 30)
                    .map(item => describe(item.element));

                const report = [
                    'viewport=' + window.innerWidth + 'x' + window.innerHeight,
                    'url=' + location.href,
                    '',
                    'MAIN',
                    describe(main),
                    '',
                    'TEXTBOX',
                    describe(textbox),
                    '',
                    'ELEMENTS_AT_CHAT_FOOTER x=' + chatX + ' y=' + footerY,
                    ...elementsAt(chatX, footerY),
                    '',
                    'ELEMENTS_ABOVE_FOOTER x=' + chatX + ' y=' + aboveFooterY,
                    ...elementsAt(chatX, aboveFooterY),
                    '',
                    'ELEMENTS_AT_TEXTBOX x=' + chatX + ' y=' + textboxY,
                    ...elementsAt(chatX, textboxY),
                    '',
                    'BOTTOM_NEAR_CANDIDATES',
                    ...candidates
                ].join('\\n');

                return report;
            })();
            """

            webView?.evaluateJavaScript(script) { result, error in
                Task { @MainActor in
                    let report: String

                    if let error {
                        report = "Layout debug failed: \(error.localizedDescription)"
                    } else {
                        report = result as? String ?? "Layout debug returned no report."
                    }

                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)

                    let alert = NSAlert()
                    alert.messageText = "Layout Debug Copied"
                    alert.informativeText = "The Messenger layout report was copied to the clipboard. Paste it back into Codex."
                    alert.runModal()
                }
            }
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
