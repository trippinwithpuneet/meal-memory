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

    /// Demo mode has no signed-in user, but the import Edge Function requires a
    /// real JWT — and rightly so: it fetches user-supplied URLs and calls Claude,
    /// so it must never accept unauthenticated callers. An anonymous session gives
    /// demo users the genuine import path without weakening that gate.
    ///
    /// Created lazily, on first import only, so simply opening the app doesn't
    /// mint an anon user. The Edge Function already falls back to `user.id` when
    /// there's no member row, so rate limiting keys correctly with no server change.
    @discardableResult
    func signInAnonymouslyIfNeeded() async throws -> Session {
        if let session { return session }
        let anonSession = try await client.auth.signInAnonymously()
        session = anonSession
        return anonSession
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
