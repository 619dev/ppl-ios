# PaperPhoneLite for iOS

The iOS client for PaperPhoneLite. It is built with React, TypeScript, Vite, and Capacitor. The shared frontend tracks the `client/` directory of [619dev/PaperPhoneLite](https://github.com/619dev/PaperPhoneLite), with platform adaptations informed by the matching Android client. The current release is PaperPhoneLite iOS 3.1.1.

[中文](README.md) · [Changelog](changelog.md) · [AGPL-3.0 License](LICENSE)

Current iOS release: `3.1.1 (57)`; bundle ID: `com.fm619tech.paperphonelite`.

## 3.1.1 release highlights

- Removed the unused proxy settings entry and subpage from Profile.
- Synchronized upstream `9bf6aaf` (3.1.0), adding signed private messages, contact identity verification, and identity-change notices.
- Added signed groups, trusted-member checks, sender-key rotation, and offline history recovery across key epochs.
- Improved paginated message sync, cache-before-cursor persistence, and account isolation.
- Added security text in eight languages and the upstream security regression tests.
- Preserved iOS Tor, Keychain, Bark, local notifications, Share Extension, and iPad adaptations; updated to 3.1.1 (57).

## Privacy and network model

Production PaperPhoneLite servers run as Tor v3 onion services. Tor conceals the server's public IP, and both Android and iOS use an embedded Tor client to reach `.onion` addresses, with no clearnet fallback for the application server. Every app launch starts Tor, including launches that restore an existing signed-in session; if a direct circuit is not established within 20 seconds, the client obtains a WebTunnel bridge from Tor Project Moat and switches automatically. WebTunnel assists Tor bootstrap only; application traffic continues to reach the onion service through the embedded Tor client.

The app itself does not register an Apple Push Notification service (APNs) device token. iOS users may optionally configure Bark: the PaperPhoneLite server sends only the sender name and a generic new-message alert to Bark, whose iOS app displays it through APNs. Without Bark, a suspended or terminated app receives no remote background notification. While running and connected, WebSocket events can still produce local notifications and in-app alerts.

The project also integrates no FCM, Firebase, OneSignal, or Web Push. Android may optionally use ntfy and iOS may optionally use Bark. These are independent third parties, and their privacy and metadata risks depend on the selected instance.

## Current functionality

- Private and group chats, contacts, and group management
- Text, image, video, voice, file, emoji, and sticker messages
- Authenticated attachment downloads through the configured PaperPhoneLite server, with the iOS share sheet for saving or forwarding files
- X25519 key agreement, XSalsa20-Poly1305 message encryption, and Ed25519 message signatures
- Signed group Sender Keys, member identity checks, and key rotation
- Optional extra message password with eight ciphertext text appearances
- Message synchronization, offline cache, expiration, and cache clearing
- QR features, TOTP two-factor authentication, recovery codes, and device sessions
- Multiple servers and proxies with Tor-only onion-address validation
- Automatic Tor bootstrap before login or registration, with automatic WebTunnel fallback
- Chinese, English, Japanese, Korean, French, German, Russian, and Spanish UI
- iOS Keychain protection and an iOS share extension
- Local notifications and unread badges while the app is running

The Lite client does not provide Moments, Timeline, public posting, voice calls, video calls, or meetings. Historical components that are not connected to application routes may remain in the repository; they are not current release features.

## Notification limitations

| Platform/state | Behavior |
|---|---|
| iOS running with WebSocket connected | In-app alerts; local system notifications when permission is granted |
| iOS suspended or terminated | Bark app alert when configured; otherwise messages synchronize when reopened |
| Android | Optional ntfy depending on client and server configuration |

Local notifications are created on the device from messages already received through Tor/WebSocket; they do not pass through APNs. The home-screen badge reflects only the unread state currently known to the app and does not imply background delivery.

## Security boundaries

End-to-end encryption protects message content but does not hide operational metadata such as account relationships, group membership, time, type, size, or delivery state. It cannot protect a compromised device, screenshots, or content saved or forwarded by a recipient. Tor reduces network-address exposure but does not guarantee anonymity or remove linkability from device fingerprints and account behavior. Independently verify safety numbers before sensitive communication.

The optional extra message password is never uploaded or automatically synchronized. It remains in process memory only while unlocked; the device stores salt and verification data. This is an additional layer above normal E2EE, not a substitute for device security, strong passwords, or secure system storage.

## Identity verification and compatibility

Both participants enable and unlock the same text-appearance password agreed offline in Message Privacy, then verify identity from the contact profile. The protocol verification text is always `paperphone.app`; a green check appears after mutual verification and signed receipts complete. Do not send this password through chat or another online channel. Identity-key changes require verification again; compare safety numbers through an independent channel too.

Signed private messages in 3.1.0 use X25519, XSalsa20-Poly1305, and Ed25519. The code retains ML-KEM protocol support, but the current sending path does not enable ML-KEM and does not establish post-quantum protection for current messages. Group key distributions and new messages bind member identities, the group, and the key epoch. Unsigned historical messages are not verified messages.

Use servers and peers supporting the 3.1.0 signature protocol and group key-epoch APIs. Older clients may not process new signed messages; coordinate server and peer upgrades. The upstream baseline is `9bf6aaf` (2026-10-17).

## Technology

- React 19, TypeScript 5.7, Vite 6, and Zustand
- Capacitor 8 and iOS 17+
- Tor 0.4.9.11 and IPtProxy 5.5.1 (WebTunnel)
- libsodium-wrappers-sumo and crystals-kyber-js
- iOS Keychain and CryptoKit AES-256-GCM
- `@capacitor/local-notifications` for on-device notifications only
- `@capawesome/capacitor-badge` for local unread badges

The project does not depend on `@capacitor/push-notifications`.

## Build

Requirements: Node.js 22+, npm 9+, CocoaPods, Xcode 26+, and macOS.

```bash
git clone https://github.com/619dev/ppl-ios
cd ppl-ios
npm ci
npm run build
npx cap sync ios
(cd ios/App && pod install)
```

Open `ios/App/App.xcworkspace` in Xcode (not the `.xcodeproj`), configure your own signing, and run. Never commit `.p8`, `.mobileprovision`, IPA, or other signing material to the source repository.

Command-line builds must also target `ios/App/App.xcworkspace`. Building the `.xcodeproj` directly omits the complete CocoaPods dependency graph for Tor and IPtProxy and can fail to resolve those modules in a clean environment.

The App Store build uses `com.fm619tech.paperphonelite`; its Share Extension uses `com.fm619tech.paperphonelite.share`. Archiving and upload require the distributor's Apple Distribution certificate, matching App Store provisioning profiles, and App Store Connect access.

Attachment downloads accept only same-origin `/api/files/` URLs from the currently configured server and include the active login token. If that token has expired, the client refreshes the session and retries. This prevents attachment actions from handing onion URLs to the system browser or downloading unexpected cross-origin content.

## Validation and development

Run from the repository root:

```bash
npm run test:security
npm run test:i18n
npm run build
npx cap sync ios
xcodebuild -workspace ios/App/App.xcworkspace -scheme App \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/ppl-ios-derived CODE_SIGNING_ALLOWED=NO build
```

See [test coverage and limitations](tests/README.md). This 3.1.0 update passed the frontend build, security regressions, checks for 92 security text keys across eight languages, and unsigned device-target compilation of the app and Share Extension. Unsigned output is not a distribution build; live device interoperability remains untested. A subsequent simulator build with `CODE_SIGNING_ALLOWED=YES` succeeded and the app was launched.

Capacitor plugins use Swift Package Manager; Tor and IPtProxy use CocoaPods. Keep both dependency systems and build the workspace. After frontend changes, rebuild and run `cap sync ios` to update bundled native resources.

## Data and self-hosting responsibility

Account and routing metadata, encrypted messages, and attachments are handled by the PaperPhoneLite server selected by the user. User and group avatars use the permanent storage class, while ordinary chat attachments use the temporary storage class; actual cleanup and retention are controlled by the server. Its operator is responsible for the onion service, storage, backups, retention, access control, applicable law, and optional ntfy configuration. The project operates no unified messaging service and provides no official APNs relay.

See the in-app Privacy Policy and Terms of Use for the complete disclosures.

## License

This repository is released under the [GNU Affero General Public License v3.0](LICENSE), consistent with PaperPhoneLite upstream. You may run, study, modify, and redistribute it. Distribution of modified versions and network use of a modified service are subject to the corresponding AGPL-3.0 source-availability obligations. No warranty of quality, security, merchantability, or fitness is provided; the [LICENSE](LICENSE) text controls the exact rights and obligations.

Third-party dependencies remain subject to their own licenses. Mention of Apple, the Tor Project, ntfy, or another third party does not make that party an operator or guarantor of this project.
