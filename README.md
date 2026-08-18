# PaperPhoneLite iOS 客户端

PaperPhoneLite 的 iOS 客户端。项目使用 React、TypeScript、Vite 与 Capacitor 构建，公共前端以上游 [619dev/PaperPhoneLite](https://github.com/619dev/PaperPhoneLite) 的 `client/` 目录为基线，并参考同版本 Android 客户端进行平台适配。

[English](README_EN.md) · [更新日志](changelog.md) · [AGPL-3.0 许可证](LICENSE)

当前 iOS 版本：`3.0.8 (46)`；Bundle ID：`com.fm619tech.paperphonelite`。

## 隐私与网络模型

PaperPhoneLite 的生产服务运行在 Tor v3 onion service 上。服务器的公开 IP 由 Tor 隐藏，Android 与 iOS 客户端均使用内嵌 Tor 访问 `.onion` 地址，不提供应用服务器的明网回退。登录或注册页会自动启动 Tor；直连 20 秒仍未建链时，客户端会从 Tor Project Moat 获取 WebTunnel 网桥并自动切换。WebTunnel 仅用于帮助建立 Tor 线路，应用业务流量仍通过内嵌 Tor 访问 onion service。

本项目完全不使用 Apple Push Notification service（APNs），不会注册 APNs 设备令牌，也不会把设备令牌或通知载荷发送给 Apple、官方中继或其他 APNs 中继。原因是 APNs 必须通过明网推送基础设施及中继交付，这会破坏 Tor-only 部署的信任和元数据边界。应用被 iOS 挂起或终止后不会收到后台远程消息通知；应用处于运行和连接状态时，可根据 WebSocket 收到的事件生成本地通知和应用内提醒。

项目也不集成 FCM、Firebase、OneSignal 或 Web Push。Android 可由用户或服务器运营者选择 ntfy；ntfy 属于独立第三方服务，其隐私政策和元数据风险由所选实例决定。

## 实际功能

- 私聊与群聊、联系人和群组管理
- 文字、图片、视频、语音、文件、表情与贴纸消息
- X25519 与 ML-KEM-768 混合密钥协商、XSalsa20-Poly1305 消息加密
- 加密群聊 Sender Key、会话安全号码验证
- 可选的额外消息密码与八种密文文本外观
- 消息同步、离线缓存、自动删除和缓存清理
- 二维码、TOTP 两步验证、恢复码和设备会话管理
- 多服务器与代理配置、Tor-only onion 地址校验
- 登录和注册前自动建立 Tor 线路，并自动获取 WebTunnel 网桥回退
- 中、英、日、韩、法、德、俄、西八种界面语言
- iOS Keychain 身份密钥保护、系统分享扩展
- 应用运行时的本地通知和未读角标

本 Lite 客户端不提供朋友圈、时间线、公开内容发布、语音通话、视频通话或会议功能。仓库中可能保留尚未接入路由的历史组件，它们不属于当前发布功能。

## 通知限制

| 平台/状态 | 行为 |
|---|---|
| iOS 应用运行且 WebSocket 已连接 | 应用内提醒；获得本地通知权限后可显示本地系统通知 |
| iOS 应用被系统挂起或终止 | 无远程后台通知；重新打开后同步消息 |
| Android | 可选 ntfy，具体取决于客户端和服务器配置 |

本地通知由设备根据已通过 Tor/WebSocket 收到的消息生成，不经过 APNs。主屏角标仅反映应用本地已知的未读数，不代表后台接收能力。

## 安全边界

端到端加密保护消息内容，但不会隐藏账号关系、群成员、时间、消息类型、大小和投递状态等服务运行所需元数据，也不能防止设备失陷、截图或收件人保存和转发。Tor 用于降低网络地址暴露，但不保证绝对匿名，也不能消除设备指纹或账号行为形成的关联。进行敏感通信前应独立核对安全号码。

额外消息密码不会上传或自动同步。密码只在解锁期间保留于进程内存，本地保存盐和验证数据。它是原有端到端加密之上的附加层，不能替代设备锁、强密码或系统安全存储。

## 技术栈

- React 19、TypeScript 5.7、Vite 6、Zustand
- Capacitor 8、iOS 17+
- Tor 0.4.9.11、IPtProxy 5.5.1（WebTunnel）
- libsodium-wrappers-sumo、crystals-kyber-js
- iOS Keychain、CryptoKit AES-256-GCM
- `@capacitor/local-notifications`：仅限设备本地通知
- `@capawesome/capacitor-badge`：本地未读角标

项目不依赖 `@capacitor/push-notifications`。

## 构建

要求 Node.js 18+、npm 9+、CocoaPods、Xcode 26+ 与 macOS。

```bash
git clone https://github.com/619dev/ppl-ios
cd ppl-ios
npm install
npm run build
npx cap sync ios
cd ios/App && pod install
```

随后使用 Xcode 打开 `ios/App/App.xcworkspace`（不要打开 `.xcodeproj`），配置自己的签名并运行。任何 `.p8`、`.mobileprovision`、IPA 和其他签名材料都不应提交到源码仓库。

App Store 发行包使用 Bundle ID `com.fm619tech.paperphonelite`；分享扩展使用 `com.fm619tech.paperphonelite.share`。归档和上传需要发行者自己的 Apple Distribution 证书、对应 App Store provisioning profiles，以及 App Store Connect 权限。

## 数据与自托管责任

账号及路由元数据、加密消息和附件由用户选择的 PaperPhoneLite 服务器处理。服务器运营者负责 onion service、数据存储、备份、保留期限、访问控制、适用法律和可选 ntfy 配置。项目不运营统一消息服务，也不提供官方 APNs 中继。

应用内完整说明见“隐私政策”和“使用条款”。

## 许可证

本仓库按 [GNU Affero General Public License v3.0](LICENSE) 发布，与 PaperPhoneLite 上游保持一致。您可以运行、研究、修改和再分发软件；分发修改版或通过网络向用户提供修改后的服务时，必须遵守 AGPL-3.0 的相应源码提供义务。许可证不提供质量、安全、适销性或特定用途保证；准确权利与义务以 [LICENSE](LICENSE) 原文为准。

第三方依赖仍适用各自许可证。Apple、Tor Project、ntfy 及其他第三方不因被提及而成为本项目的运营者或担保方。
