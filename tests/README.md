# Validation: security, localization, and iOS layout

Run from the iOS repository root after `npm ci`:

```bash
npm run test:session
npm run test:security
npm run test:i18n
npm run build
npx cap sync ios
```

Imported from PaperPhoneLite upstream `9bf6aaf` (3.1.0).

- `sessionGate.test.cjs`: slow local crypto restoration renders a loading page without navigation; checks ready, signed-out, and account-switch states. Prevents the iOS history replacement limit that previously caused a blank screen after login.
- `authenticatedMessaging.test.cjs`: signed messages, tampering, mutual identity verification, replay protection, identity replacement and trust invalidation.
- `signedGroups.test.cjs`: signed key distribution, membership changes, key rotation, offline history across epochs and account isolation.
- `sync.test.cjs`: complete pagination, deduplication, cache-before-cursor persistence, failures and account changes.
- `securityI18n.test.cjs`: 92 security keys across eight languages, placeholders, duplicate keys and locale changes.

The cryptographic suites use real sodium, X25519, PBKDF2 and AES-GCM with in-memory adapters for network and secret storage. They do not exercise native Keychain, Tor, WebView lifecycle or live server interoperability; those require device testing against a compatible 3.1.0 server.

## 3.1.2 (58) adaptation checks

On 2026-10-20, the adaptation passed `test:security`, `test:i18n`, the production frontend build, Capacitor iOS sync, property-list validation, and an unsigned Xcode 27.1 simulator build. The Duo outer-display login launched and was inspected in a screenshot. See [iPhone 17 / Duo acceptance notes](ios-device-compatibility.md) for pending inner-display, folding, keyboard, signed-in, and physical-device checks.

## Historical verification: 3.1.0 (56)

On 2026-10-17, `test:security`, `test:i18n`, the production frontend build, Capacitor iOS sync, and unsigned `iphoneos` compilation of the app and Share Extension passed. Simulator validation was blocked by a local CoreSimulator/Xcode version mismatch. These results do not establish live-device or live-server interoperability.

For native setup and the workspace build command, see the [project guide](../README_EN.md) / [中文说明](../README.md). Capacitor CLI 8 requires Node.js 22 or newer. The native build uses both SPM for Capacitor plugins and CocoaPods for Tor/IPtProxy.
