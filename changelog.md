# Changelog / 更新日志

All notable changes and new features are recorded here. Historical entries below were migrated from the repository documentation.

所有重要版本改动和新特性统一记录于此。下方历史条目由仓库原有文档迁移而来。

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
