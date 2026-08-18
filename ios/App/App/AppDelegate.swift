import UIKit
import Capacitor
import UserNotifications
import CryptoKit
import Security

@objc(PaperPhoneBridgeViewController)
public class PaperPhoneBridgeViewController: CAPBridgeViewController {
    public override func capacitorDidLoad() {
        bridge?.registerPluginInstance(SecureStoragePlugin())
        bridge?.registerPluginInstance(KeepAwakePlugin())
        bridge?.registerPluginInstance(SharedFilePlugin())
    }
}

@objc(SharedFile)
public class SharedFilePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SharedFile"
    public let jsName = "SharedFile"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getPending", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clearPending", returnType: CAPPluginReturnPromise)
    ]

    private let appGroup = "group.com.fm619tech.paperphoneplus"
    private let metadataKey = "pendingSharedFile"

    @objc func getPending(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let metadata = defaults.dictionary(forKey: metadataKey),
              let relativePath = metadata["relativePath"] as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            call.resolve(["file": NSNull()])
            return
        }
        let fileURL = container.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            defaults.removeObject(forKey: metadataKey)
            call.resolve(["file": NSNull()])
            return
        }
        call.resolve(["file": [
            "id": metadata["id"] as? String ?? "",
            "name": metadata["name"] as? String ?? fileURL.lastPathComponent,
            "mimeType": metadata["mimeType"] as? String ?? "application/octet-stream",
            "size": metadata["size"] as? NSNumber ?? 0,
            "path": fileURL.path
        ]])
    }

    @objc func clearPending(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { call.resolve(); return }
        let metadata = defaults.dictionary(forKey: metadataKey)
        if let requestedID = call.getString("id"),
           let storedID = metadata?["id"] as? String,
           requestedID != storedID {
            call.resolve()
            return
        }
        if let relativePath = metadata?["relativePath"] as? String,
           let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(relativePath))
        }
        defaults.removeObject(forKey: metadataKey)
        call.resolve()
    }
}

@objc(SecureStorage)
public class SecureStoragePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SecureStorage"
    public let jsName = "SecureStorage"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "seal", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "open", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setSecret", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getSecret", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "deleteSecret", returnType: CAPPluginReturnPromise)
    ]

    private let service = "com.fm619tech.paperphoneplus.secure-storage.v1"

    private func keyName(_ account: String) -> String { "master.\(account)" }

    private func readKeychain(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return data
    }

    private func writeKeychain(account: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            guard retryStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(retryStatus))
            }
            return
        }
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }

    private func deleteKeychain(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func masterKey(account: String) throws -> SymmetricKey {
        let name = keyName(account)
        if let data = try readKeychain(account: name) { return SymmetricKey(data: data) }
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        try writeKeychain(account: name, data: bytes)
        return SymmetricKey(data: bytes)
    }

    private func required(_ call: CAPPluginCall, _ name: String) -> String? {
        guard let value = call.getString(name), !value.isEmpty else {
            call.reject("Missing \(name)")
            return nil
        }
        return value
    }

    @objc func seal(_ call: CAPPluginCall) {
        guard let account = required(call, "account"), let purpose = required(call, "purpose"),
              let plaintext = call.getString("plaintext") else { return }
        do {
            let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: masterKey(account: account), authenticating: Data("ppp:v1:\(account):\(purpose)".utf8))
            guard let combined = sealed.combined else { throw NSError(domain: "SecureStorage", code: 1) }
            call.resolve(["ciphertext": combined.base64EncodedString()])
        } catch { call.reject("Encryption failed", nil, error) }
    }

    @objc func open(_ call: CAPPluginCall) {
        guard let account = required(call, "account"), let purpose = required(call, "purpose"),
              let encoded = required(call, "ciphertext") else { return }
        guard let combined = Data(base64Encoded: encoded) else { call.reject("Invalid ciphertext"); return }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let plaintext = try AES.GCM.open(box, using: masterKey(account: account), authenticating: Data("ppp:v1:\(account):\(purpose)".utf8))
            guard let value = String(data: plaintext, encoding: .utf8) else { throw NSError(domain: "SecureStorage", code: 2) }
            call.resolve(["plaintext": value])
        } catch { call.reject("Decryption failed", nil, error) }
    }

    @objc func setSecret(_ call: CAPPluginCall) {
        guard let account = required(call, "account"), let name = required(call, "name"),
              let value = call.getString("value") else { return }
        do { try writeKeychain(account: "secret.\(account).\(name)", data: Data(value.utf8)); call.resolve() }
        catch { call.reject("Keychain write failed", nil, error) }
    }

    @objc func getSecret(_ call: CAPPluginCall) {
        guard let account = required(call, "account"), let name = required(call, "name") else { return }
        do {
            let data = try readKeychain(account: "secret.\(account).\(name)")
            call.resolve(["value": data.flatMap { String(data: $0, encoding: .utf8) } ?? NSNull()])
        } catch { call.reject("Keychain read failed", nil, error) }
    }

    @objc func deleteSecret(_ call: CAPPluginCall) {
        guard let account = required(call, "account"), let name = required(call, "name") else { return }
        do { try deleteKeychain(account: "secret.\(account).\(name)"); call.resolve() }
        catch { call.reject("Keychain delete failed", nil, error) }
    }
}

@objc(KeepAwake)
public class KeepAwakePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "KeepAwake"
    public let jsName = "KeepAwake"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setEnabled", returnType: CAPPluginReturnPromise)
    ]

    @objc func setEnabled(_ call: CAPPluginCall) {
        let enabled = call.getBool("enabled") ?? false
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = enabled
            call.resolve()
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set notification center delegate so foreground notifications show system banners
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // ── APNs: Device token registration (forward to Capacitor) ──

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationCenter.default.post(
            name: .capacitorDidRegisterForRemoteNotifications,
            object: deviceToken
        )
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(
            name: .capacitorDidFailToRegisterForRemoteNotifications,
            object: error
        )
    }

    // ── APNs: Handle background/silent push notifications ──

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NotificationCenter.default.post(
            name: NSNotification.Name.init("didReceiveRemoteNotification"),
            object: userInfo
        )
        completionHandler(.newData)
    }

    // ── UNUserNotificationCenterDelegate: Show banner even when app is in foreground ──

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // ── UNUserNotificationCenterDelegate: Handle notification tap ──

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    // ── App lifecycle ──

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
