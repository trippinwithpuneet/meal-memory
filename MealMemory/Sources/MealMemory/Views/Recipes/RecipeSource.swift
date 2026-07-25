import SwiftUI

// TRI-27 — where an imported recipe came from, derived from Recipe.sourceUrl.
// Uses monochrome SF Symbols (trademark-safe, native) rather than brand logos.
enum RecipeSource {
    case youtube, tiktok, instagram, pinterest, web

    /// Detect the platform from a stored source URL. Returns nil for hand-added
    /// recipes (no URL) or anything that isn't a valid http(s) link.
    static func detect(from urlString: String?) -> RecipeSource? {
        guard let raw = urlString?.trimmingCharacters(in: .whitespaces), !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased()
        else { return nil }

        if host.contains("youtube") || host.contains("youtu.be") { return .youtube }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("instagram") { return .instagram }
        if host.contains("pinterest") || host.contains("pin.it") { return .pinterest }
        return .web
    }

    var name: String {
        switch self {
        case .youtube:   return "YouTube"
        case .tiktok:    return "TikTok"
        case .instagram: return "Instagram"
        case .pinterest: return "Pinterest"
        case .web:       return "Web"
        }
    }

    var symbol: String {
        switch self {
        case .youtube:   return "play.rectangle.fill"
        case .tiktok:    return "music.note"
        case .instagram: return "camera.fill"
        case .pinterest: return "pin.fill"
        case .web:       return "safari.fill"
        }
    }
}

// Option B — a small labeled chip for the recipe row.
struct SourceChip: View {
    let source: RecipeSource
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.symbol).font(.system(size: 9, weight: .semibold))
            Text(source.name).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

// Option B — a bordered "View on {platform}" button for the detail view.
// Opens the source; for https links iOS routes to the native app automatically
// (universal links) when it's installed, else Safari.
struct SourceLinkButton: View {
    let source: RecipeSource
    let urlString: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
                  (url.scheme?.lowercased() == "https") else { return }
            openURL(url)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: source.symbol).font(.system(size: 14))
                Text("View on \(source.name)").font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            .foregroundColor(Theme.navy)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
