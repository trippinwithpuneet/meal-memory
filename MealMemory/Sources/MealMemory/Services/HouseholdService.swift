import Foundation
import Supabase

@MainActor
final class HouseholdService: ObservableObject {
    private let client = AppSupabase.client

    // MARK: - Household

    func createHousehold(name: String) async throws -> UUID {
        guard AuthService.shared.userId != nil else { throw AppError.notAuthenticated }

        // Creation + creator membership happen atomically in a SECURITY DEFINER
        // function so no permissive client-side members INSERT policy is needed.
        return try await client
            .rpc("create_household", params: [
                "p_name": name,
                "p_display_name": defaultDisplayName()
            ])
            .execute()
            .value
    }

    func fetchHousehold(id: UUID) async throws -> Household {
        try await client
            .from("households")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    // MARK: - Members

    func fetchMembers(householdId: UUID) async throws -> [Member] {
        try await client
            .from("members")
            .select()
            .eq("household_id", value: householdId)
            .execute()
            .value
    }

    func updateMember(memberId: UUID, displayName: String, dietaryRestrictions: [String]) async throws {
        try await client
            .from("members")
            .update([
                "display_name": AnyJSON.string(displayName),
                "dietary_restrictions": AnyJSON.array(dietaryRestrictions.map { .string($0) })
            ])
            .eq("id", value: memberId)
            .execute()
    }

    func updateAPNSToken(memberId: UUID, tokens: [String]) async throws {
        try await client
            .from("members")
            .update(["apns_device_tokens": AnyJSON.array(tokens.map { .string($0) })])
            .eq("id", value: memberId)
            .execute()
    }

    // MARK: - Invite Flow

    func generateInviteToken(householdId: UUID) async throws -> String {
        guard let userId = AuthService.shared.userId else { throw AppError.notAuthenticated }
        let token = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })

        try await client
            .from("invite_tokens")
            .insert([
                "household_id": householdId.uuidString,
                "token": token,
                "created_by": userId.uuidString
            ])
            .execute()

        return token
    }

    func claimInviteToken(_ token: String) async throws -> UUID {
        guard AuthService.shared.userId != nil else { throw AppError.notAuthenticated }

        // Validation, membership, and burning the token happen atomically in a
        // SECURITY DEFINER function — the client never reads invite tokens, so
        // there's nothing to enumerate.
        do {
            return try await client
                .rpc("redeem_invite_token", params: [
                    "p_token": token.uppercased(),
                    "p_display_name": defaultDisplayName()
                ])
                .execute()
                .value
        } catch {
            // The function raises for a missing / expired / used token.
            throw AppError.invalidInviteToken
        }
    }

    // MARK: - Private

    private func defaultDisplayName() -> String {
        guard let email = AuthService.shared.session?.user.email else { return "" }
        let prefix = email.components(separatedBy: "@").first ?? ""
        return prefix.prefix(1).uppercased() + prefix.dropFirst()
    }

}

enum AppError: LocalizedError {
    case notAuthenticated
    case invalidInviteToken
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:    return "You need to be signed in to do that."
        case .invalidInviteToken:  return "That invite code is invalid or has expired."
        case .unknown(let msg):    return msg
        }
    }
}
