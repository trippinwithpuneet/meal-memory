import Foundation
import Supabase

@MainActor
final class MealPlanService: ObservableObject {
    private let client = AppSupabase.client

    // MARK: - Fetch week

    func fetchWeek(householdId: UUID, startDate: Date) async throws -> [MealSlot] {
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate)!
        let formatter = DateFormatter.isoDate

        return try await client
            .from("meal_slots")
            .select()
            .eq("household_id", value: householdId)
            .gte("slot_date", value: formatter.string(from: startDate))
            .lte("slot_date", value: formatter.string(from: endDate))
            .execute()
            .value
    }

    // MARK: - Upsert slot (place or move recipe)

    func upsertSlot(householdId: UUID, date: Date, mealType: MealType, recipeId: UUID?) async throws -> MealSlot {
        guard let userId = AuthService.shared.userId else { throw AppError.notAuthenticated }
        let formatter = DateFormatter.isoDate
        let now = Date()

        // Client-generated ID for INSERT path — on conflict (UPDATE) the DB keeps its own ID,
        // but slotKey is date+mealType so local state stays consistent regardless of ID.
        var payload: [String: AnyJSON] = [
            "id":           .string(UUID().uuidString),
            "household_id": .string(householdId.uuidString),
            "slot_date":    .string(formatter.string(from: date)),
            "meal_type":    .string(mealType.rawValue),
            "updated_by":   .string(userId.uuidString),
            "updated_at":   .string(ISO8601DateFormatter().string(from: now))
        ]
        payload["recipe_id"] = recipeId.map { .string($0.uuidString) } ?? .null

        // Fire-and-forget UPSERT — return local object immediately.
        let c = client
        let p = payload
        Task.detached { try? await c.from("meal_slots").upsert(p, onConflict: "household_id,slot_date,meal_type").execute() }

        return MealSlot(
            id: UUID(),
            householdId: householdId,
            slotDate: date,
            mealType: mealType,
            recipeId: recipeId,
            updatedBy: userId,
            updatedAt: now
        )
    }

    // MARK: - Swap two slots

    func swapSlots(householdId: UUID,
                   slotA: MealSlot, slotB: MealSlot) async throws -> (MealSlot, MealSlot) {
        // Write A's recipe into B's slot, and B's recipe into A's slot.
        async let updatedA = upsertSlot(householdId: householdId,
                                        date: slotA.slotDate,
                                        mealType: slotA.mealType,
                                        recipeId: slotB.recipeId)
        async let updatedB = upsertSlot(householdId: householdId,
                                        date: slotB.slotDate,
                                        mealType: slotB.mealType,
                                        recipeId: slotA.recipeId)
        return try await (updatedA, updatedB)
    }

    // MARK: - Clear slot

    func clearSlot(householdId: UUID, date: Date, mealType: MealType) async throws {
        try await upsertSlot(householdId: householdId, date: date, mealType: mealType, recipeId: nil)
    }

    // MARK: - Realtime subscription

    func subscribeToWeek(householdId: UUID, onUpdate: @escaping (MealSlot) -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("meal_slots:\(householdId)")
        channel.onPostgresChange(
            InsertAction.self,
            table: "meal_slots",
            filter: "household_id=eq.\(householdId)"
        ) { change in
            if let slot = try? change.decodeRecord(as: MealSlot.self, decoder: JSONDecoder.supabase) {
                onUpdate(slot)
            }
        }
        channel.onPostgresChange(
            UpdateAction.self,
            table: "meal_slots",
            filter: "household_id=eq.\(householdId)"
        ) { change in
            if let slot = try? change.decodeRecord(as: MealSlot.self, decoder: JSONDecoder.supabase) {
                onUpdate(slot)
            }
        }
        Task { await channel.subscribe() }
        return channel
    }
}

// MARK: - Helpers

extension DateFormatter {
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
