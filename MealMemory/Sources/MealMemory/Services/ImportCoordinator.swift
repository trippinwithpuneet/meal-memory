import Foundation

/// Bridges links shared into the app (via the Share Extension's `mealmemory://`
/// deep link or the App Group fallback) to the Add Recipe sheet.
@MainActor
final class ImportCoordinator: ObservableObject {
    // Keep in sync with ShareViewController in the ShareExtension target.
    static let appGroup = "group.com.puneetjain.mealmemory"
    static let pendingKey = "pendingImportURL"

    struct PendingImport: Identifiable {
        let id = UUID()
        let url: URL
    }

    @Published var pending: PendingImport?

    /// Handle a `mealmemory://import?url=...` deep link from the Share Extension.
    func handle(_ deepLink: URL) {
        guard deepLink.scheme == "mealmemory", deepLink.host == "import" else { return }
        let comps = URLComponents(url: deepLink, resolvingAgainstBaseURL: false)
        if let raw = comps?.queryItems?.first(where: { $0.name == "url" })?.value,
           let url = URL(string: raw) {
            present(url)
        }
        clearAppGroupPending()
    }

    /// Fallback: on activation, pick up anything the extension stashed in the
    /// App Group (covers the case where the responder-chain open didn't fire).
    func checkAppGroupPending() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup),
              let raw = defaults.string(forKey: Self.pendingKey),
              let url = URL(string: raw) else { return }
        clearAppGroupPending()
        present(url)
    }

    private func present(_ url: URL) {
        pending = PendingImport(url: url)
    }

    private func clearAppGroupPending() {
        UserDefaults(suiteName: Self.appGroup)?.removeObject(forKey: Self.pendingKey)
    }
}
