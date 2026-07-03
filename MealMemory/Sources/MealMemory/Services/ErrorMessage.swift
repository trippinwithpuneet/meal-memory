import Foundation

// Single source of truth for user-facing error copy. Every screen maps thrown
// errors through this so users never see raw Postgres / network / SDK jargon
// like "new row violates row-level security policy for table households".
extension Error {
    func userMessage(fallback: String = "Something went wrong. Please try again.") -> String {
        // Our own typed errors already carry friendly text.
        if let appError = self as? AppError, let described = appError.errorDescription {
            return described
        }

        let raw = localizedDescription.lowercased()

        // Connectivity
        if raw.contains("network") || raw.contains("offline") || raw.contains("connection")
            || raw.contains("timed out") || raw.contains("internet") || raw.contains("cancelled") {
            return "Can't reach the server. Check your connection and try again."
        }

        // Auth
        if raw.contains("invalid login") || raw.contains("invalid credentials") {
            return "That email or password doesn't match. Give it another try."
        }
        if raw.contains("already registered") || raw.contains("already been registered") {
            return "An account with this email already exists. Try signing in instead."
        }
        if raw.contains("email") && raw.contains("valid") {
            return "That doesn't look like a valid email address."
        }
        if raw.contains("password") && (raw.contains("least") || raw.contains("short")
            || raw.contains("6 char") || raw.contains("weak")) {
            return "Your password needs to be at least 6 characters."
        }
        if raw.contains("confirm") && raw.contains("email") {
            return "Check your inbox to confirm your email, then sign in."
        }

        // Permissions / RLS
        if raw.contains("row-level security") || raw.contains("violates")
            || raw.contains("permission denied") || raw.contains("not authorized")
            || raw.contains("jwt") || raw.contains("not authenticated") {
            return "We couldn't complete that. Try signing out and back in, then try again."
        }

        // Invites
        if raw.contains("invite") || raw.contains("token") {
            return "That invite code is invalid or has expired."
        }

        return fallback
    }
}
