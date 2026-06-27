import Foundation
import Supabase

@MainActor
final class HouseholdService: ObservableObject {
    private let client = AppSupabase.client

    // MARK: - Household

    func createHousehold(name: String) async throws -> UUID {
        guard AuthService.shared.userId != nil else { throw AppError.notAuthenticated }

        // Generate UUID client-side so we can insert without .select() — inserting
        // with return=representation would fail because the SELECT policy requires
        // the user to already be a member, but we haven't added them yet.
        let householdId = UUID()
        try await client
            .from("households")
            .insert(["id": householdId.uuidString, "name": name])
            .execute()

        // Add creator as member — now the SELECT policy will pass
        try await joinHousehold(householdId: householdId, displayName: defaultDisplayName())

        return householdId
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

        let invite: InviteToken = try await client
            .from("invite_tokens")
            .select()
            .eq("token", value: token.uppercased())
            .is("used_at", value: nil)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .single()
            .execute()
            .value

        try await joinHousehold(householdId: invite.householdId, displayName: defaultDisplayName())

        try await client
            .from("invite_tokens")
            .update(["used_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: invite.id)
            .execute()

        return invite.householdId
    }

    // MARK: - Private

    private func defaultDisplayName() -> String {
        guard let email = AuthService.shared.session?.user.email else { return "" }
        let prefix = email.components(separatedBy: "@").first ?? ""
        return prefix.prefix(1).uppercased() + prefix.dropFirst()
    }

    private func joinHousehold(householdId: UUID, displayName: String) async throws {
        guard let userId = AuthService.shared.userId else { throw AppError.notAuthenticated }
        try await client
            .from("members")
            .insert([
                "household_id": householdId.uuidString,
                "user_id": userId.uuidString,
                "display_name": displayName
            ])
            .execute()
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
