import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    private let client = AppSupabase.client

    @Published var session: Session?
    @Published var isLoading = false

    private init() {
        Task { await refreshSession() }
        observeAuthChanges()
    }

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session?.user.id }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response = try await client.auth.signUp(email: email, password: password)
        session = response.session
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response = try await client.auth.signIn(email: email, password: password)
        session = response
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
    }

    private func refreshSession() async {
        session = try? await client.auth.session
    }

    private func observeAuthChanges() {
        Task {
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .signedIn:  self.session = session
                    case .signedOut: self.session = nil
                    case .tokenRefreshed: self.session = session
                    default: break
                    }
                }
            }
        }
    }
}
