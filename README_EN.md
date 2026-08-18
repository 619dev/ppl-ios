# PaperPhoneLite for iOS

The iOS client for PaperPhoneLite. It is built with React, TypeScript, Vite, and Capacitor. The shared frontend tracks the `client/` directory of [619dev/PaperPhoneLite](https://github.com/619dev/PaperPhoneLite), with platform adaptations informed by the matching Android client.

[中文](README.md) · [Changelog](changelog.md) · [AGPL-3.0 License](LICENSE)

Current iOS release: `3.0.8 (46)`; bundle ID: `com.fm619tech.paperphonelite`.

## Privacy and network model

Production PaperPhoneLite servers run as Tor v3 onion services. Tor conceals the server's public IP, and both Android and iOS use an embedded Tor client to reach `.onion` addresses, with no clearnet fallback for the application server. The login and registration screen starts Tor automatically; if a direct circuit is not established within 20 seconds, the client obtains a WebTunnel bridge from Tor Project Moat and switches automatically. WebTunnel assists Tor bootstrap only; application traffic continues to reach the onion service through the embedded Tor client.

This project does not use Apple Push Notification service (APNs) at all. It does not register APNs device tokens or send device tokens or notification payloads to Apple, an official relay, or any other APNs relay. APNs requires delivery through clearnet push infrastructure and a relay, which conflicts with the trust and metadata boundary of a Tor-only deployment. When iOS suspends or terminates the app, it receives no remote background message notifications. While the app is running and connected, WebSocket events may produce on-device local notifications and in-app alerts.

The project also integrates no FCM, Firebase, OneSignal, or Web Push. Android may optionally use ntfy if enabled by the user or server operator. ntfy is an independent third party, and its privacy and metadata risks depend on the selected instance.

## Current functionality

- Private and group chats, contacts, and group management
- Text, image, video, voice, file, emoji, and sticker messages
- Hybrid X25519 and ML-KEM-768 key agreement with XSalsa20-Poly1305 message encryption
- Sender Keys for encrypted groups and safety-number verification
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
| iOS suspended or terminated | No remote background notification; messages synchronize when reopened |
| Android | Optional ntfy depending on client and server configuration |

Local notifications are created on the device from messages already received through Tor/WebSocket; they do not pass through APNs. The home-screen badge reflects only the unread state currently known to the app and does not imply background delivery.

## Security boundaries

End-to-end encryption protects message content but does not hide operational metadata such as account relationships, group membership, time, type, size, or delivery state. It cannot protect a compromised device, screenshots, or content saved or forwarded by a recipient. Tor reduces network-address exposure but does not guarantee anonymity or remove linkability from device fingerprints and account behavior. Independently verify safety numbers before sensitive communication.

The optional extra message password is never uploaded or automatically synchronized. It remains in process memory only while unlocked; the device stores salt and verification data. This is an additional layer above normal E2EE, not a substitute for device security, strong passwords, or secure system storage.

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

Requirements: Node.js 18+, npm 9+, CocoaPods, Xcode 26+, and macOS.

```bash
git clone https://github.com/619dev/ppl-ios
cd ppl-ios
npm install
npm run build
npx cap sync ios
cd ios/App && pod install
```

Open `ios/App/App.xcworkspace` in Xcode (not the `.xcodeproj`), configure your own signing, and run. Never commit `.p8`, `.mobileprovision`, IPA, or other signing material to the source repository.

The App Store build uses `com.fm619tech.paperphonelite`; its Share Extension uses `com.fm619tech.paperphonelite.share`. Archiving and upload require the distributor's Apple Distribution certificate, matching App Store provisioning profiles, and App Store Connect access.

## Data and self-hosting responsibility

Account and routing metadata, encrypted messages, and attachments are handled by the PaperPhoneLite server selected by the user. Its operator is responsible for the onion service, storage, backups, retention, access control, applicable law, and optional ntfy configuration. The project operates no unified messaging service and provides no official APNs relay.

See the in-app Privacy Policy and Terms of Use for the complete disclosures.

## License

This repository is released under the [GNU Affero General Public License v3.0](LICENSE), consistent with PaperPhoneLite upstream. You may run, study, modify, and redistribute it. Distribution of modified versions and network use of a modified service are subject to the corresponding AGPL-3.0 source-availability obligations. No warranty of quality, security, merchantability, or fitness is provided; the [LICENSE](LICENSE) text controls the exact rights and obligations.

Third-party dependencies remain subject to their own licenses. Mention of Apple, the Tor Project, ntfy, or another third party does not make that party an operator or guarantor of this project.
