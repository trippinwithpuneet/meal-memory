import UIKit
import UniformTypeIdentifiers

/// Thin Share Extension: captures the shared link, hands it to the main app,
/// and gets out of the way. The main app owns the auth session + import flow,
/// so no Supabase session is duplicated here.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    // Keep these in sync with ImportCoordinator in the main app.
    private let appGroup = "group.com.puneetjain.mealmemory"
    private let pendingKey = "pendingImportURL"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let url = await extractURL() else { complete(); return }

        // Fallback path: persist so the app can pick it up on next activation
        // even if the responder-chain open doesn't fire.
        UserDefaults(suiteName: appGroup)?.set(url.absoluteString, forKey: pendingKey)

        openHostApp(with: url)
        complete()
    }

    private func extractURL() async -> URL? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] {
                // Prefer a real web URL attachment.
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let loaded = await loadItem(provider, UTType.url.identifier) {
                    if let u = loaded as? URL { return u }
                    if let n = loaded as? NSURL { return n as URL }
                }
            }
            // Some apps (TikTok, IG) share the link as plain text instead.
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let loaded = await loadItem(provider, UTType.plainText.identifier),
                   let s = (loaded as? String) ?? (loaded as? NSString) as String?,
                   let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                   u.scheme?.hasPrefix("http") == true {
                    return u
                }
            }
        }
        return nil
    }

    private func loadItem(_ provider: NSItemProvider, _ typeId: String) async -> NSSecureCoding? {
        await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                cont.resume(returning: item)
            }
        }
    }

    /// Open the host app via its custom scheme by walking the responder chain
    /// to reach `UIApplication.open(_:)` (extensions can't call it directly).
    private func openHostApp(with url: URL) {
        var comps = URLComponents()
        comps.scheme = "mealmemory"
        comps.host = "import"
        comps.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let deepLink = comps.url else { return }

        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                _ = r.perform(selector, with: deepLink)
                return
            }
            responder = r.next
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
