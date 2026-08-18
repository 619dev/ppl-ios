# PaperPhone+ iOS Client

**ppp-ios** — The iOS native client fork of PaperPhone+, wrapping the React web app into a native iOS application using Capacitor.

[![React](https://img.shields.io/badge/React-19-blue)](#) [![TypeScript](https://img.shields.io/badge/TypeScript-5.7-blue)](#) [![Capacitor](https://img.shields.io/badge/Capacitor-8-green)](#) [![Vite](https://img.shields.io/badge/Vite-6-purple)](#) [![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](LICENSE)

🌐 **中文版：** [README.md](README.md)

---

## Changelog

The complete release history has moved to [changelog.md](changelog.md).

---

## About

This repository is the **iOS native client** fork of [PaperPhone+](https://github.com/619dev/Paperphone-plus). PaperPhone+ is a WeChat-style end-to-end encrypted instant messaging application featuring stateless ECDH + XSalsa20-Poly1305 per-message encryption with forward secrecy.

This project uses [Capacitor](https://capacitorjs.com/) to package the React + TypeScript frontend as a native iOS application, with APNS push notification support. It is available on the [App Store](https://apps.apple.com/us/app/paperphoneplus/id6769265178).

---

## Features

| Feature | Description |
|---------|-------------|
| 🔐 End-to-End Encryption | Stateless ECDH + XSalsa20-Poly1305, per-message ephemeral keys, forward secrecy |
| 🛡️ Post-Quantum Encryption | Integrated CRYSTALS-Kyber post-quantum key encapsulation |
| 🗝️ Secure Local Keys | Identity and group Sender Keys are held in the iOS Keychain; chat caches use a device-bound AES-256-GCM key |
| 📹 Video/Voice Calls | LiveKit SFU-based private and group voice/video calls |
| 🧑‍🏫 Meeting Controls | Host mute-all, discussion/lecture modes, participant list, and speaking status |
| 🎙️ Real-time Voice Changer | 3 modes (0.8x / 1.0x / 1.2x), powered by Web Audio API |
| 👥 Group Chat | Up to 2000 members, encrypted & unencrypted modes |
| 💬 Messaging | Text, images, videos, documents, voice messages, emoji panel, Telegram sticker packs |
| 📴 Offline Browsing | Caches contacts, groups, chat history, Moments, Timeline posts, and media, with one-tap cleanup |
| 📷 QR Scanner | Uses native `BarcodeDetector` with a `jsQR` fallback for iOS WKWebView |
| 🌐 Moments | Post updates, likes, comments, tag-based visibility control |
| 📰 Timeline | Xiaohongshu-style waterfall feed, anonymous posting supported |
| 🔔 APNS Push | Native Apple Push Notification Service |
| 🔴 App Badge | Keeps the iOS home-screen badge synchronized with the in-app unread count |
| 🌍 Multi-language | Chinese, English, Japanese, Korean, French, German, Russian, Spanish |
| 🔑 Two-Factor Auth | TOTP (Google Authenticator compatible) + recovery codes |
| 📱 Persistent Sessions | Keeps users signed in across network, proxy, or IP changes; signs out only on explicit server revocation |

---

## 🔐 Extra-encrypted text appearance: design and security boundary

This feature is **extra insurance on top of the existing end-to-end encryption (E2EE)**. It does not replace E2EE with a visual encoding, and it never bypasses or weakens the original encryption. Private chats remain protected by the existing X25519 / ML-KEM-768 key agreement and message-encryption path; group chats continue to use the Sender Key protocol. Identity private keys and group Sender Keys remain protected by iOS Keychain.

When enabled, every message is processed in this order:

1. The sender first protects the message body with the extra password shared by both participants or by all group members. PBKDF2-SHA-256 (210,000 iterations and a random salt) derives an AES-256-GCM key; every message has an independent random IV and an authentication tag for integrity.
2. The complete extra-encryption frame (version, salt, IV, and ciphertext) is then encoded with one of eight selectable text appearances. This is not merely decorative character substitution: the visible characters carry the extra encrypted ciphertext.
3. That appearance ciphertext then enters the project's original encryption path: private-chat E2EE or group Sender Key encryption. The server still receives the original E2EE/Sender-Key ciphertext plus metadata required for delivery.
4. The recipient reverses the order: first decrypt the original E2EE/Sender-Key layer, then decode the text-appearance frame and decrypt the body with the extra password.

The extra password is never uploaded, synchronized automatically, or distributed by the server. Both people in a private chat must set the same password; every group member who needs to read the plaintext must also set that same password. Text appearances do not need to match: every message carries its own appearance identifier, so the recipient automatically detects and decodes the sender's choice. For example, one person may send Buddhist text while another sends Hangul; if the extra password matches, both decrypt normally. A user's appearance setting controls only the ciphertext appearance of messages they send. If the password is missing, locked, or different, messages are still sent and received normally and the original E2EE layer still decrypts successfully, but the app can display only the appearance ciphertext—not the original text.

The app does not persist the extra password. While unlocked it exists only in the current process memory; locally, the app stores only a random salt and AES-GCM verification data used to check whether an entered password is correct. Users can lock immediately or automatically 5, 15, 30, or 60 minutes after the app leaves the foreground. This layer adds an independent shared secret beyond E2EE; it does not replace a strong password, device lock, or system secure storage, and it cannot provide absolute protection on a fully compromised device while the password remains in memory.

## Tech Stack

```
Frontend
  React 19 + TypeScript 5.7 + Vite 6
  Zustand — State management
  libsodium-wrappers-sumo — Curve25519 / XSalsa20-Poly1305 (WebAssembly)
  crystals-kyber-js — Post-quantum key encapsulation
  LiveKit Client — SFU-based private and group voice/video calls
  Web Audio API — Real-time voice modulation
  jsQR — QR decoding fallback for iOS WKWebView

Native Layer (Capacitor 8)
  @capacitor/ios — iOS native bridge
  @capacitor/push-notifications — APNS push
  @capacitor/local-notifications — Local notifications
  @capacitor/splash-screen — Splash screen
  @capacitor/status-bar — Status bar control
  @capacitor/app — App lifecycle
  @capawesome/capacitor-badge — iOS app badge synchronization
```

---

## Project Structure

```
ppp-ios/
├── index.html                  # HTML entry point
├── capacitor.config.ts         # Capacitor config (appId, HTTPS scheme, etc.)
├── vite.config.ts              # Vite build configuration
├── package.json                # Dependencies
├── tsconfig.json               # TypeScript configuration
├── ios/                        # Xcode native project directory
├── src/
│   ├── main.tsx                # React entry point
│   ├── App.tsx                 # Routing + auth guard
│   ├── index.css               # Design system (dark/light, glassmorphism)
│   ├── api/                    # HTTP + WebSocket clients
│   ├── crypto/
│   │   ├── ratchet.ts          # ECDH + XSalsa20-Poly1305 encryption
│   │   ├── keystore.ts         # 4-layer private key persistence
│   │   └── groupCrypto.ts      # Group encryption (Sender Key protocol)
│   ├── hooks/                  # React Hooks
│   ├── i18n/                   # Internationalization (8 languages)
│   ├── store/                  # Zustand state management
│   ├── components/             # Shared components
│   ├── contexts/               # React Contexts
│   ├── utils/                  # Utility functions
│   └── pages/
│       ├── Login.tsx           # Login / Registration
│       ├── Chats.tsx           # Conversation list
│       ├── Chat.tsx            # Chat window
│       ├── Contacts.tsx        # Contact list
│       ├── Discover.tsx        # Discovery page
│       ├── Profile.tsx         # Settings
│       ├── UserProfile.tsx     # Contact profile
│       ├── GroupInfo.tsx        # Group info
│       ├── Moments.tsx         # Moments (social feed)
│       └── Timeline.tsx        # Timeline (waterfall feed)
├── public/                     # Static assets
├── assets/                     # App assets
├── dist/                       # Build output
└── build/                      # Build artifacts
```

---

## Requirements

- **Node.js** ≥ 18
- **npm** ≥ 9
- **Xcode** ≥ 15 (with iOS 17+ SDK)
- **CocoaPods** (for iOS native dependencies)
- macOS (required for iOS development)

---

## Getting Started

### 1. Clone the Repository

```bash
git clone <repo-url> && cd ppp-ios
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Local Development (Web Preview)

```bash
npm run dev
# Open http://localhost:5173
```

### 4. Build and Sync to iOS

```bash
# Build the frontend
npm run build

# Sync to Capacitor iOS project
npx cap sync ios

# Open in Xcode
npx cap open ios
```

### 5. Run in Xcode

1. Select your target device or simulator in Xcode
2. Configure signing (Signing & Capabilities)
3. Click Run (⌘R)

---

## APNS Push Notification Setup

This project uses APNS (Apple Push Notification Service) for native push notifications.

### Prerequisites

1. A valid Apple Developer account
2. Create an APNS Key (.p8 file) in the Apple Developer Portal
3. Enable Push Notifications capability in Xcode

### Backend Configuration

Configure in the backend `server/.env`:

```env
APNS_TEAM_ID=your_team_id
APNS_KEY_ID=your_key_id
APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
APNS_BUNDLE_ID=com.fm619tech.paperphoneplus
APNS_SANDBOX=false    # Use true for TestFlight, false for App Store
```

Or use the official push relay (no Apple credentials needed):

```env
APNS_RELAY_URL=https://619.chat
APNS_RELAY_KEY=EzmpqftbsENaRUO6BTABxLV96q7RuEDyokXJr1DWdDjL54cLg7yXVUQqydCQvxrX
```

When a push or message arrives, or a conversation is marked as read, the app recalculates the total unread count and synchronizes the iOS home-screen badge.

---

## Group Meetings

Group voice and video meetings use a LiveKit SFU, so each device maintains only one upstream connection and can scale better for multi-party calls. The backend `/api/calls/meeting-token` endpoint supplies meeting credentials and participant limits; a full deployment therefore requires a LiveKit service configured on the backend.

- The meeting creator becomes the host and can mute everyone.
- In discussion mode, participants can unmute themselves. Switching to lecture mode mutes non-host participants and prevents them from unmuting.
- The client enables adaptive stream and dynacast to reduce bandwidth usage in multi-party video meetings.

---

## Login Session Behavior

Ordinary network loss, WebSocket reconnection, proxy changes, IP changes, or a single HTTP 401 response do not immediately clear local login state. The client signs out only after an explicit server signal for session revocation, forced logout, account disablement, or account deletion.

---

## Upstream Project

This project is the iOS client fork of [619dev/PaperPhoneLite](https://github.com/619dev/PaperPhoneLite). Its shared frontend tracks PaperPhoneLite's `client/` directory and the matching Android client, while the iOS project, push integration, Keychain support, and share extension remain maintained here.

For full system deployment (including backend server), please refer to the upstream documentation:
- 🚀 [Zeabur One-click Deployment](https://zeabur.com/templates/SK6T93?referralCode=619dev)
- 🐳 Docker Compose deployment
- ▲ Vercel frontend deployment
- 📡 Video call TURN configuration
- 🔔 Push notifications (APNS / FCM / OneSignal / ntfy / Web Push)

---

## License

This project is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE), consistent with the upstream project [619dev/PaperPhoneLite](https://github.com/619dev/PaperPhoneLite).

In summary:
- ✅ Free to use and deploy for individuals and organizations
- ✅ Modification is permitted
- ⚠️ If you provide a modified version as a network service, you **must release the modified source code**
- ⚠️ Derivative works **must use the same license** (AGPL-3.0)

See the [LICENSE](LICENSE) file for the full license text.

---

## Acknowledgments

- [PaperPhone+](https://github.com/619dev/Paperphone-plus) — Upstream project
- [Capacitor](https://capacitorjs.com/) — Cross-platform native runtime
- [libsodium](https://doc.libsodium.org/) — Cryptographic library
- [CRYSTALS-Kyber](https://pq-crystals.org/kyber/) — Post-quantum cryptography
