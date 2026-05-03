# Messenger Native macOS

A native macOS SwiftUI wrapper for Messenger using `WKWebView`.

## Run In Development

```sh
swift run
```

## Build `.app`

```sh
./scripts/build-app.sh
```

The built app is written to:

```text
dist/Messenger.app
```

## Included Features

- Persistent Messenger login through `WKWebsiteDataStore.default()`
- Custom domain setting stored in `UserDefaults`
- Custom CSS injection from `Sources/MessengerNative/Resources/custom.css`
- Dock badge updates from Messenger page title counts like `(3)`
- Native macOS notifications
- Native app menu commands for reload, CSS reload, notification test, badge test, and domain setting
- External links open in the default browser

## Notes

This is a native macOS wrapper, not a line-by-line conversion from Electron. Messenger may behave differently in `WKWebView` than in Electron/Chromium, especially around login and web notification support.
