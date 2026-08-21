# Changelog / 更新日志

All notable changes and new features are recorded here. Historical entries below were migrated from the repository documentation.

所有重要版本改动和新特性统一记录于此。下方历史条目由仓库原有文档迁移而来。

## 3.0.16 (iOS build 51) — 2026-08-21

- Fixed native Tor startup for persisted signed-in sessions so cold launches no longer remain stuck in WebSocket reconnection.
- Native Tor now starts at the application root, and WebSocket recovery is triggered immediately after the WebKit proxy becomes ready.
- Improved the startup text-appearance password prompt so its visibility stays synchronized with the actual encryption lock state.
- Prevented access-token refreshes from rehydrating presentation encryption and silently clearing a password that was just unlocked.
- Restored or reprovisioned missing local identity keys during persisted-session startup, and fetches missing recipient public keys before private-message encryption.
- Made native Tor control authentication recover from stale simulator cookies and startup cookie-replacement races instead of remaining permanently offline.
- Fixed private-message encryption after text-appearance unlock by no longer treating the Ed25519 signing key as an ML-KEM public key; optional ML-KEM failures now reliably fall back to X25519.
- Restored Android-to-iOS private-message decryption by detecting Android's legacy 56-byte X25519 envelope before parsing versioned hybrid headers.
- Reconciles the iOS public identity with its local private key after Tor/network recovery, fixing Android messages encrypted to a stale server-side iOS public key.
- Generates and persists a real ML-KEM keypair on iOS and uses its private key for Android v2 hybrid messages, replacing the invalid Ed25519-as-KEM placeholder.
- Updated the application and Share Extension versions to 3.0.16 and incremented the iOS build number to 51.

- 修复已有登录会话冷启动时未启动内置 Tor、导致 WebSocket 一直重连的问题。
- 内置 Tor 现于应用根层启动，并在 WebKit 代理就绪后立即触发 WebSocket 恢复连接。
- 改进启动时的文本外观密码弹窗，使其显示状态始终与实际加密锁定状态同步。
- 修复访问令牌刷新时重复加载文本外观加密状态、静默清除刚解锁密码的问题。
- 已有会话启动时自动恢复或重新生成缺失的本地身份密钥，并在私聊加密前补取缺失的接收方公钥。
- 修复模拟器残留 Tor 控制认证 cookie 或启动时 cookie 替换竞态导致永久离线的问题，认证失败后会重新读取并重试。
- 修复文本外观已经解锁后私聊仍可能提示加密失败的问题：不再把 Ed25519 签名公钥误作 ML-KEM 公钥，并确保可选 ML-KEM 异常时可靠回退到 X25519。
- 修复 Android 端发来的私聊消息无法解密的问题：识别 Android 旧版 56 字节 X25519 消息头，再按对应协议解密，实时消息与历史消息均兼容。
- 网络或 Tor 恢复后自动校验并同步 iOS 本地私钥对应的服务端公钥，修复 Android 使用服务端旧公钥加密、导致 iOS 无法解密新消息的问题。
- iOS 现生成并安全保存真实 ML-KEM 公私钥，使用 KEM 私钥解密 Android 发来的 v2 混合加密消息，不再把 Ed25519 签名密钥错误发布为 KEM 公钥。
- App 与分享扩展版本统一更新为 3.0.16，iOS 构建号递增至 51。

---

## 3.0.15 (iOS build 50) — 2026-08-21

- Synchronized the shared client updates from PaperPhoneLite 3.0.15 while preserving the iOS Tor, Keychain, notifications, Share Extension, calling, and iPad adaptations.
- Fixed received attachments remaining as styled ciphertext after private-chat or Sender Key decryption, restoring filenames and download access across devices.
- Added a startup password prompt for signed-in accounts with text appearance encryption enabled, including localized incorrect-password feedback in all eight supported languages.
- Updated the application version to 3.0.15 and incremented the iOS build number to 50.

- 同步 PaperPhoneLite 3.0.15 的共享客户端更新，并保留 iOS 的 Tor、Keychain、本地通知、分享扩展、通话和 iPad 适配。
- 修复私聊或 Sender Key 解密后，收到的附件仍停留在文本外观密文状态的问题，恢复跨设备文件名显示和下载访问。
- 已登录账号启用文本外观加密时，App 启动后提示输入密码，并为全部八种语言补充密码错误提示。
- 应用版本更新为 3.0.15，iOS 构建号递增至 50。

---

## 3.0.13 (iOS build 49) — 2026-08-21

- Synchronized the shared chat reliability updates from PaperPhoneLite Android 3.0.13.
- Prevented rapid duplicate message sends, file uploads, and attachment saves with synchronous operation guards.
- File messages now show an in-progress clock and disable the active download button while the authenticated attachment is being prepared for the iOS share/save sheet.
- Updated the application version to 3.0.13 and incremented the iOS build number to 49.

- 同步 PaperPhoneLite Android 3.0.13 的聊天可靠性更新。
- 使用同步操作锁防止快速重复发送消息、上传文件和保存附件。
- 鉴权附件正在准备并调起 iOS 分享/存储面板时，文件消息显示处理中图标并禁用当前下载按钮。
- 应用版本更新为 3.0.13，iOS 构建号递增至 49。

---

## 3.0.12 (iOS build 48) — 2026-08-21

- Synchronized the shared client with PaperPhoneLite upstream 3.0.12.
- Added authenticated attachment downloads through the configured PaperPhoneLite server, including one automatic access-token refresh and retry.
- File messages now open the native iOS share/save sheet when supported, with an in-WebView download fallback.
- Restricted attachment downloads to same-origin `/api/files/` URLs so onion links are not handed to the system browser and cross-origin files are rejected.
- Added localized download-failure messages for Chinese, English, Japanese, Korean, French, German, Russian, and Spanish.
- Updated the application version to 3.0.12 and incremented the iOS build number to 48 while preserving the existing Tor, Keychain, notifications, Share Extension, and iPad adaptations.

- 公共客户端代码同步至 PaperPhoneLite 上游 3.0.12。
- 新增通过当前 PaperPhoneLite 服务器鉴权下载附件；访问令牌过期时会自动刷新一次并重试。
- 文件消息在环境支持时调起 iOS 系统分享/存储面板，并保留 WebView 内下载回退。
- 附件下载仅允许当前服务器同源的 `/api/files/` 地址，避免将 onion 链接交给系统浏览器，并拒绝跨来源文件。
- 为中文、英文、日文、韩文、法文、德文、俄文和西班牙文补充下载失败提示。
- 应用版本更新为 3.0.12，iOS 构建号递增至 48，同时保留现有 Tor、Keychain、本地通知、分享扩展和 iPad 适配。

---

## 3.0.8 (iOS build 47) — 2026-08-19

- Added native responsive layouts for every supported iPad size, orientation, Split View width, and Stage Manager window size.
- Replaced the phone-width authentication surface on full-size iPads with a spacious two-column brand and sign-in layout; compact iPad windows automatically use a full-width single-column layout.
- Adapted headers, lists, search, chat spacing and bubble widths, input bars, modals, and the floating tab bar for iPad displays.

- 新增适用于全部受支持 iPad 尺寸、横竖屏、分屏宽度和台前调度窗口尺寸的响应式布局。
- 全尺寸 iPad 登录与注册页改为品牌区和表单区双栏布局；较窄的 iPad 窗口自动切换为满宽单栏布局。
- 同步适配页面标题、列表、搜索、聊天间距与气泡宽度、输入栏、弹窗和悬浮底部导航。

---

## 3.0.8 (iOS build 46) — 2026-08-19

- Rebased the iOS client on PaperPhoneLite 3.0.8 and aligned its application identity with `com.fm619tech.paperphonelite`.
- Embedded Tor for all onion-service application traffic. Login and registration now start Tor automatically, then obtain and activate a Tor Project Moat WebTunnel bridge when direct bootstrap does not complete in time.
- Corrected native WebView routing so registration and login requests use the embedded Tor SOCKS path instead of failing through the default network stack.
- Removed APNs integration and all remote-push claims. Notifications are local only and require the app to have already received the event while running.
- Updated the app icon and light/dark launch artwork to match the Android PaperPhoneLite client.
- Updated multilingual Tor/WebTunnel status and error copy, privacy disclosures, licensing notes, build instructions, and release documentation.

- iOS 客户端重新基于 PaperPhoneLite 3.0.8 整合，应用标识统一为 `com.fm619tech.paperphonelite`。
- 所有 onion service 业务流量均通过内嵌 Tor。登录和注册页会自动启动 Tor；直连未及时完成时，自动从 Tor Project Moat 获取并启用 WebTunnel 网桥。
- 修正原生 WebView 路由，使注册和登录请求走内嵌 Tor SOCKS 通道，不再错误使用系统默认网络栈而出现 `Load failed`。
- 移除 APNs 集成及所有远程推送表述；通知仅在应用运行且已收到事件后由设备本地生成。
- App 图标及浅色、深色启动画面与 Android PaperPhoneLite 客户端保持一致。
- 更新八种语言的 Tor/WebTunnel 状态和错误提示，以及隐私声明、许可说明、构建步骤和发布文档。

---

## 2.4.7

- Fixed E2EE safety-number mismatches by deriving both views from the same pair of published identity keys; text appearance and its extra password remain independent of the E2EE safety number.
- Fixed one-to-one video calls that could play audio while leaving the remote video black; remote LiveKit tracks now use native track attachment and explicit mobile playback.
- Fixed the call-duration race that could leave an established call at `00:00`.
- Added ordered multi-image sending with a maximum of 20 images per selection and per-image upload progress.
- Added per-account, per-conversation scroll-position memory and a one-tap button to jump to the latest message.
- Updated the application and native platform versions to `2.4.7`.

- 修复 E2EE 安全号码不一致：双方现在基于服务器发布的同一对身份公钥计算；文本外观及其额外密码仍与 E2EE 安全号码相互独立。
- 修复私聊视频通话只有声音、远端画面黑屏的问题；远端 LiveKit 媒体改用原生轨道绑定，并显式兼容移动端播放。
- 修复通话已经接通但计时器停留在 `00:00` 的事件竞态。
- 新增多图片发送：一次最多选择 20 张，保持选择顺序并显示逐张上传进度。
- 新增按账号、按会话保存屏幕滚动位置，以及一键跳到最新消息按钮。
- 应用及原生平台版本统一更新为 `2.4.7`。

---

# Historical entries from README.md

## 2.4.6 更新说明

- 文本外观现已明确定位为原有端对端加密之上的额外保险：消息正文先由共享额外密码加密并转换为所选外观，再进入私聊 E2EE（X25519 / ML-KEM-768）或群聊 Sender Key 加密链路。
- 私聊双方或群内所有成员需要自行约定并设置相同的额外密码；密码不会上传服务器或自动同步。
- 密码不一致时，原有 E2EE 和消息送达仍正常，但接收方只能看到文本外观密文，无法查看原文。
- 该功能不会替代、绕过或降级原有 E2EE；个人信息 > 消息隐私页面的 8 种语言说明已同步更新。

## 2.4.4 更新说明

- 修复额外加密锁定状态下错误显示“设置密码”的问题；现在显示“输入解锁密码”，并同步全部 8 种语言。

- 修复关闭额外文本外观加密时未验证密码的安全问题；现在即使已解锁，也必须重新输入正确的额外密码才能关闭。
- 文本外观现已隐藏协议元数据，发送中的本地缓存不再保留消息原文。
- 额外聊天记录加密已移至个人信息 > 消息隐私，并全局应用于所有聊天。

- 加密发送改为失败即停止，不再因加密或密钥分发错误回退为明文；消息会显示实际采用的 `PQ v2`、`X25519 ↓` 或 `SK vN`。
- 新增可选聊天记录额外密码、8 种文本外观编码，以及应用离开前台 5/15/30/60 分钟后的自动锁定。
- 未解锁或密码错误时仅显示文本外观密文；身份私钥与 Sender Key 继续由 iOS Keychain 保护，并补齐 8 种语言界面。

## 2.4.0 更新说明

- 新增 iOS 系统分享扩展，可从“文件”、照片及其他应用将文件发送给 PaperPhoneLite 联系人。

## 2.3.9 更新说明

- 修复历史单向好友记录导致“已是好友”但联系人列表不可见、无法聊天的问题；再次添加时会自动补齐双向关系并立即刷新好友列表。

## 2.3.8 更新说明

- 修复在相机权限弹窗期间关闭扫码器后，摄像头仍可能保持运行的问题。
- 修复扫码页返回按钮的触控层级，确保 iOS 上可以可靠关闭扫码器。
- 好友搜索结果会标记并禁用已经是好友的用户，避免重复发送好友申请。

## 2.3.7 更新说明

- 修复新安装或保留登录态升级后，本机缺少身份私钥时应用无法启动的问题。
- 启动时会安全恢复或初始化身份密钥，并清理迁移过程中遗留的无效 Keychain 数据。
- 服务端暂时不可用时不再阻塞本地安全状态初始化，恢复联网后可继续完成密钥同步。

---

---

# Historical entries from README_EN.md

## What's New in 2.4.6

- Text appearance is now clearly documented as extra insurance above the existing end-to-end encryption: the shared extra password encrypts and renders the body first, followed by private-chat E2EE (X25519 / ML-KEM-768) or group Sender Key encryption.
- Both private-chat participants, or every group member, must agree on and configure the same extra password; it is never uploaded or synchronized.
- If passwords differ, E2EE and delivery still work, but recipients see only styled ciphertext and cannot read the original body.
- This feature never replaces, bypasses, or downgrades the original E2EE; the Profile > Message privacy explanation is updated in all eight UI languages.

## What's New in 2.4.4

- Fixed the locked extra-encryption dialog so it requests the unlock password instead of asking users to set one, across all eight languages.

- Fixed a security issue that allowed extra text-appearance encryption to be disabled without password verification; the correct extra password must now be re-entered even while unlocked.
- Text appearance now hides protocol metadata and optimistic caches no longer retain original message bodies.
- Extra message-history encryption moved to Profile > Message privacy and applies globally to all chats.

- Encrypted sends now fail closed instead of falling back to plaintext, and each message reports its actual `PQ v2`, `X25519 ↓`, or `SK vN` protocol.
- Added an optional chat-history password, eight presentation codecs, and automatic locking 5/15/30/60 minutes after leaving the foreground.
- Locked or incorrectly unlocked histories show presentation ciphertext only; identity private keys and Sender Keys remain protected by iOS Keychain, with complete UI copy in all eight languages.

## What's New in 2.4.0

- Added an iOS Share Extension for sending files from Files, Photos, and other apps to PaperPhoneLite contacts.

## What's New in 2.3.9

- Fixed legacy one-way friendship records causing an “Already friends” message while the contact remained invisible and unavailable for chat; adding the user again now repairs both directions and refreshes the contact list immediately.

## What's New in 2.3.8

- Fixed the camera potentially remaining active when the scanner is closed during the permission prompt.
- Fixed the scanner back button's touch layering for reliable closing on iOS.
- Existing friends are now identified and disabled in user search results to prevent duplicate requests.

## What's New in 2.3.7

- Fixed an app startup failure on fresh installs or upgrades that retained a session without a local identity key.
- Identity keys are now securely restored or initialized during startup, and invalid Keychain data left by interrupted migrations is removed.
- Temporary server unavailability no longer blocks local secure-state initialization; key synchronization can continue after connectivity is restored.

---
