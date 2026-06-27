import Foundation

struct ImportedRecipe {
    let name: String
    let emoji: String?
    let ingredients: [String]
    let steps: [String]
}

final class RecipeImportService {
    static let shared = RecipeImportService()
    private init() {}

    private var lastImportDate: Date?
    private let rateLimitInterval: TimeInterval = 5  // 1 import per 5 seconds per device

    func importRecipe(from url: URL) async throws -> ImportedRecipe {
        // Client-side rate limit (server Edge Function enforces household-level)
        if let last = lastImportDate, Date().timeIntervalSince(last) < rateLimitInterval {
            throw ImportError.rateLimited
        }
        lastImportDate = Date()

        // Resolve Pinterest links (follow redirects to source blog URL)
        let resolvedURL = url.host?.contains("pinterest") == true
            ? try await resolveRedirects(url)
            : url

        // Call Supabase Edge Function (bypasses mobile CORS)
        guard
            let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let base = URL(string: supabaseURL)
        else { throw ImportError.configuration }

        let functionURL = base.appendingPathComponent("functions/v1/fetch-recipe")
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let session = await AuthService.shared.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let body = try JSONSerialization.data(withJSONObject: ["url": resolvedURL.absoluteString])
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ImportError.fetchFailed
        }

        return try parseResponse(data)
    }

    // MARK: - Private

    private func parseResponse(_ data: Data) throws -> ImportedRecipe {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.parseFailed
        }
        let name        = json["name"] as? String ?? ""
        let ingredients = json["ingredients"] as? [String] ?? []
        let steps       = json["steps"] as? [String] ?? []
        guard !name.isEmpty else { throw ImportError.parseFailed }
        return ImportedRecipe(name: name, emoji: nil, ingredients: ingredients, steps: steps)
    }

    private func resolveRedirects(_ url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        let (_, response) = try await URLSession.shared.data(for: request)
        return response.url ?? url
    }

    enum ImportError: LocalizedError {
        case rateLimited, configuration, fetchFailed, parseFailed

        var errorDescription: String? {
            switch self {
            case .rateLimited:   return "Please wait a moment before importing another recipe."
            case .configuration: return "App configuration error — missing Supabase URL."
            case .fetchFailed:   return "Couldn't reach that recipe URL."
            case .parseFailed:   return "Couldn't extract a recipe from that page."
            }
        }
    }
}
