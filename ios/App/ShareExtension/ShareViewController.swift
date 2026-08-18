import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let appGroup = "group.com.fm619tech.paperphonelite"
    private let metadataKey = "pendingSharedFile"
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "正在打开 PaperPhoneLite…"
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        receiveSharedFile()
    }

    private func receiveSharedFile() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            finishWithError("没有找到可发送的文件")
            return
        }
        let typeIdentifier = provider.registeredTypeIdentifiers.first ?? UTType.data.identifier
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, error in
            guard let self, let sourceURL, error == nil else {
                self?.finishWithError("无法读取共享文件")
                return
            }
            do {
                try self.storeAndOpen(sourceURL: sourceURL, provider: provider, typeIdentifier: typeIdentifier)
            } catch {
                self.finishWithError("无法准备共享文件")
            }
        }
    }

    private func storeAndOpen(sourceURL: URL, provider: NSItemProvider, typeIdentifier: String) throws {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
              let defaults = UserDefaults(suiteName: appGroup) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        if let old = defaults.dictionary(forKey: metadataKey), let path = old["relativePath"] as? String {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(path))
        }
        let id = UUID().uuidString
        let suggestedName = provider.suggestedName ?? sourceURL.lastPathComponent
        let safeName = suggestedName.isEmpty ? "shared-file" : suggestedName
        let destination = inbox.appendingPathComponent("\(id)-\(safeName)")
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        let values = try destination.resourceValues(forKeys: [.fileSizeKey])
        let mimeType = UTType(typeIdentifier)?.preferredMIMEType ?? "application/octet-stream"
        defaults.set([
            "id": id,
            "name": safeName,
            "mimeType": mimeType,
            "size": values.fileSize ?? 0,
            "relativePath": "ShareInbox/\(destination.lastPathComponent)"
        ], forKey: metadataKey)

        DispatchQueue.main.async {
            guard let url = URL(string: "paperphone://share") else { return }
            self.extensionContext?.open(url) { opened in
                if opened {
                    self.extensionContext?.completeRequest(returningItems: nil)
                } else {
                    self.showManualOpenNotice()
                }
            }
        }
    }

    private func showManualOpenNotice() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "文件已准备好",
                message: "请打开 PaperPhoneLite，选择联系人后即可发送。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好", style: .default) { _ in
                self.extensionContext?.completeRequest(returningItems: nil)
            })
            self.present(alert, animated: true)
        }
    }

    private func finishWithError(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "PaperPhoneLite", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "关闭", style: .default) { _ in
                self.extensionContext?.cancelRequest(withError: CocoaError(.fileReadUnknown))
            })
            self.present(alert, animated: true)
        }
    }
}
