import UIKit
import Capacitor
import UserNotifications
import CryptoKit
import Security
import WebKit
import Network
import Tor
import IPtProxy

private struct PaperPhoneRouter: Router {
    var basePath = ""

    func route(for path: String) -> String {
        if path.isEmpty || path == "/" || URL(fileURLWithPath: path).pathExtension.isEmpty {
            return basePath + "/index.html"
        }
        return basePath + path
    }
}

@objc(PaperPhoneBridgeViewController)
public class PaperPhoneBridgeViewController: CAPBridgeViewController {
    public override func router() -> Router {
        PaperPhoneRouter()
    }

    public override func capacitorDidLoad() {
        bridge?.registerPluginInstance(SecureStoragePlugin())
        bridge?.registerPluginInstance(KeepAwakePlugin())
        bridge?.registerPluginInstance(SharedFilePlugin())
        bridge?.registerPluginInstance(TorPlugin())
    }
}

@objc(TorPlugin)
public class TorPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "TorPlugin"
    public let jsName = "TorPlugin"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getStatus", returnType: CAPPluginReturnPromise)
    ]

    private enum Status: String {
        case off = "OFF", starting = "STARTING", on = "ON"
        case fetchingWebTunnel = "FETCHING_WEBTUNNEL"
        case startingWebTunnel = "STARTING_WEBTUNNEL"
        case webTunnelError = "WEBTUNNEL_ERROR"
    }

    private let socksPort = 9050
    private let queue = DispatchQueue(label: "com.fm619tech.paperphonelite.tor")
    private var status: Status = .off
    private var transport = "direct"
    private var proxyReady = false
    private var configuration: TorConfiguration?
    private var torThread: TorThread?
    private var controller: TorController?
    private var circuitObserver: Any?
    private var directTimeout: DispatchWorkItem?
    private var webTunnelTimeout: DispatchWorkItem?
    private var transportController: IPtProxyController?
    private var lastError: String?

    @objc func start(_ call: CAPPluginCall) {
        queue.async {
            if self.status == .off || self.status == .webTunnelError { self.startDirect() }
            call.resolve(self.state())
        }
    }

    @objc func getStatus(_ call: CAPPluginCall) {
        queue.async { call.resolve(self.state()) }
    }

    private func state() -> [String: Any] {
        var value: [String: Any] = [
            "status": status.rawValue, "host": "127.0.0.1", "port": socksPort,
            "ready": status == .on && proxyReady, "transport": transport
        ]
        if let lastError { value["error"] = lastError }
        return value
    }

    private func publish() {
        let value = state()
        DispatchQueue.main.async { self.notifyListeners("statusChange", data: value) }
    }

    private func startDirect() {
        lastError = nil
        guard torThread == nil else {
            if controller != nil { configureDirect() }
            return
        }
        status = .starting
        transport = "direct"
        proxyReady = false
        publish()

        do {
            let files = FileManager.default
            let root = try files.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true).appendingPathComponent("Tor", isDirectory: true)
            let cache = try files.url(for: .cachesDirectory, in: .userDomainMask,
                                      appropriateFor: nil, create: true).appendingPathComponent("Tor", isDirectory: true)
            try files.createDirectory(at: root, withIntermediateDirectories: true)
            try files.createDirectory(at: cache, withIntermediateDirectories: true)
            let config = TorConfiguration()
            config.dataDirectory = root
            config.cacheDirectory = cache
            config.autoControlPort = true
            config.socksPort = UInt(socksPort)
            config.ignoreMissingTorrc = true
            config.cookieAuthentication = true
            config.avoidDiskWrites = true
            config.clientOnly = true
            config.arguments.addObjects(from: ["--SafeSocks", "1", "--TestSocks", "1"])
            guard let controlPortFile = config.controlPortFile else {
                throw NSError(domain: "TorPlugin", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Tor control port file is unavailable"])
            }
            try? files.removeItem(at: controlPortFile)
            // A force-terminated simulator process can leave the previous
            // control cookie behind. Remove it before Tor starts so we never
            // authenticate a new control port with stale credentials.
            try? files.removeItem(at: root.appendingPathComponent("control_auth_cookie"))
            configuration = config
            let thread = TorThread(configuration: config)
            torThread = thread
            thread.start()
            connectController(controlPortFile: controlPortFile, attempt: 0)
        } catch {
            failWebTunnel(error)
        }
    }

    private func connectController(controlPortFile: URL, attempt: Int) {
        guard attempt < 300, let config = configuration else {
            failWebTunnel(NSError(domain: "TorPlugin", code: 1,
                                   userInfo: [NSLocalizedDescriptionKey: "Tor control port did not become ready"]))
            return
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: controlPortFile.path),
              (attributes[.size] as? NSNumber)?.intValue ?? 0 > 0 else {
            queue.asyncAfter(deadline: .now() + 0.1) {
                self.connectController(controlPortFile: controlPortFile, attempt: attempt + 1)
            }
            return
        }
        guard let cookie = config.cookie, !cookie.isEmpty else {
            queue.asyncAfter(deadline: .now() + 0.1) {
                self.connectController(controlPortFile: controlPortFile, attempt: attempt + 1)
            }
            return
        }
        let candidate = TorController(controlPortFile: controlPortFile)
        if candidate.isConnected {
            candidate.authenticate(with: cookie) { success, error in
                self.queue.async {
                    guard success else {
                        candidate.disconnect()
                        // The control-port file can become visible just before
                        // Tor atomically replaces its authentication cookie.
                        // Re-read both on the next attempt instead of turning a
                        // short startup race into a permanent offline state.
                        self.queue.asyncAfter(deadline: .now() + 0.1) {
                            self.connectController(controlPortFile: controlPortFile, attempt: attempt + 1)
                        }
                        return
                    }
                    self.controller = candidate
                    self.observeCircuits()
                    self.configureDirect()
                }
            }
        } else {
            queue.asyncAfter(deadline: .now() + 0.1) {
                self.connectController(controlPortFile: controlPortFile, attempt: attempt + 1)
            }
        }
    }

    private func observeCircuits() {
        guard let controller else { return }
        circuitObserver = controller.addObserver(forCircuitEstablished: { established in
            guard established else { return }
            self.queue.async {
                guard self.status == .starting || self.status == .startingWebTunnel else { return }
                self.directTimeout?.cancel()
                self.webTunnelTimeout?.cancel()
                self.applyWebKitProxy()
            }
        })
    }

    private func configureDirect() {
        guard let controller else { return }
        transportController?.stop(IPtProxyWebtunnel)
        controller.setConfs([
            ["key": "UseBridges", "value": "0"]
        ]) { _, _ in }
        status = .starting
        transport = "direct"
        publish()
        directTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.status == .starting else { return }
            self.startWebTunnelFallback()
        }
        directTimeout = timeout
        queue.asyncAfter(deadline: .now() + 20, execute: timeout)
    }

    private func applyWebKitProxy() {
        DispatchQueue.main.async {
            guard let port = NWEndpoint.Port(rawValue: UInt16(self.socksPort)) else {
                self.queue.async {
                    self.failWebTunnel(NSError(domain: "TorPlugin", code: 10,
                                               userInfo: [NSLocalizedDescriptionKey: "Invalid Tor SOCKS port"]))
                }
                return
            }
            var proxy = ProxyConfiguration(socksv5Proxy: .hostPort(host: "127.0.0.1", port: port))
            // Never bypass Tor if the local SOCKS listener is unavailable.
            proxy.allowFailover = false
            let dataStore = self.bridge?.webView?.configuration.websiteDataStore
                ?? WKWebsiteDataStore.default()
            dataStore.proxyConfigurations = [proxy]
            self.queue.async {
                self.proxyReady = true
                self.status = .on
                self.publish()
            }
        }
    }

    private func startWebTunnelFallback() {
        lastError = nil
        status = .fetchingWebTunnel
        transport = "webtunnel"
        proxyReady = false
        publish()
        fetchLatestWebTunnel { result in
            self.queue.async {
                switch result {
                case .success(let bridge): self.configureWebTunnel(bridge: bridge)
                case .failure(let error):
                    if let cached = self.validBridge(UserDefaults.standard.string(forKey: "tor.webtunnel.bridge")) {
                        self.configureWebTunnel(bridge: cached)
                    } else { self.failWebTunnel(error) }
                }
            }
        }
    }

    private func fetchLatestWebTunnel(completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "https://bridges.torproject.org/moat/circumvention/settings")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PaperPhoneLite/3.0.16 (iOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(#"{"country":"cn","transports":["webtunnel"]}"#.utf8)
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        URLSession(configuration: config).dataTask(with: request) { data, response, error in
            if let error { completion(.failure(error)); return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
                completion(.failure(NSError(domain: "TorPlugin", code: 4))); return
            }
            do {
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let settings = root?["settings"] as? [[String: Any]] ?? []
                for item in settings {
                    guard let bridges = item["bridges"] as? [String: Any],
                          bridges["type"] as? String == "webtunnel",
                          let values = bridges["bridge_strings"] as? [String] else { continue }
                    for value in values {
                        if let bridge = self.validBridge(value) {
                            UserDefaults.standard.set(bridge, forKey: "tor.webtunnel.bridge")
                            completion(.success(bridge)); return
                        }
                    }
                }
                throw NSError(domain: "TorPlugin", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "No WebTunnel bridge returned"])
            } catch { completion(.failure(error)) }
        }.resume()
    }

    private func validBridge(_ input: String?) -> String? {
        guard let value = input?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.hasPrefix("webtunnel "), !value.contains("\n"), !value.contains("\r"),
              value.contains(" url=https://"),
              value.range(of: #"\sver=[0-9.]+(?:\s|$)"#, options: .regularExpression) != nil else { return nil }
        // IPtProxy's randomized uTLS profile can select hybrid curves that its
        // mobile Go runtime cannot generate. Standard TLS is explicitly
        // supported by the WebTunnel bridge-line format and avoids that crash.
        return value.range(of: #"\sutls="#, options: .regularExpression) == nil
            ? value + " utls=none"
            : value
    }

    private func configureWebTunnel(bridge: String) {
        do {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("webtunnel-pt", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if transportController == nil {
                transportController = IPtProxyController(directory.path, enableLogging: false,
                                                         unsafeLogging: false, logLevel: "INFO", transportEvents: nil)
            }
            try transportController?.start(IPtProxyWebtunnel, proxy: nil)
            let port = transportController?.port(IPtProxyWebtunnel) ?? 0
            guard (1...65535).contains(port), let controller else { throw NSError(domain: "TorPlugin", code: 7) }
            let quote: (String) -> String = {
                "\"" + $0.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"") + "\""
            }
            controller.setConfs([
                ["key": "UseBridges", "value": "1"],
                ["key": "ClientTransportPlugin", "value": quote("webtunnel socks5 127.0.0.1:\(port)")],
                ["key": "Bridge", "value": quote(bridge)]
            ]) { success, error in
                self.queue.async {
                    guard success else { self.failWebTunnel(error ?? NSError(domain: "TorPlugin", code: 8)); return }
                    self.status = .startingWebTunnel
                    self.publish()
                    let timeout = DispatchWorkItem { [weak self] in
                        guard let self, self.status == .startingWebTunnel else { return }
                        self.failWebTunnel(NSError(domain: "TorPlugin", code: 9,
                                                   userInfo: [NSLocalizedDescriptionKey: "WebTunnel connection timed out"]))
                    }
                    self.webTunnelTimeout = timeout
                    self.queue.asyncAfter(deadline: .now() + 45, execute: timeout)
                }
            }
        } catch { failWebTunnel(error) }
    }

    private func failWebTunnel(_ error: Error) {
        NSLog("[TorPlugin] %@", error.localizedDescription)
        lastError = error.localizedDescription
        status = .webTunnelError
        proxyReady = false
        publish()
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

    private let appGroup = "group.com.fm619tech.paperphonelite"
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

    private let service = "com.fm619tech.paperphonelite.secure-storage.v1"

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
