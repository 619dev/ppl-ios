# CapApp-SPM

PaperPhoneLite iOS 3.1.2 (58) uses this package to connect Capacitor 8 and its native plugins through Swift Package Manager. The minimum deployment target remains iOS 17. Use Xcode 27.1 or newer for the current iPhone 17 / Duo adaptation. Scene lifecycle and safe-area/keyboard handling live in the app target, not in this generated package.

`Package.swift` and the package wiring are managed by the Capacitor CLI. Change plugin dependencies in the root `package.json`, install them, then run these commands from the repository root:

```bash
npm run build
npx cap sync ios
```

Do not hand-edit generated package dependencies. Tor and IPtProxy remain CocoaPods dependencies in `../Podfile`; this package does not replace them. Run `(cd ios/App && pod install)` from the repository root when setting up CocoaPods, then open or build `ios/App/App.xcworkspace`.

See the root [English README](../../../README_EN.md) or [中文说明](../../../README.md) for setup, unsigned build commands, signing and validation limits.
