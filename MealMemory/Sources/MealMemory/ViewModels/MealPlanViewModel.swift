import Foundation
import Supabase

@MainActor
final class MealPlanViewModel: ObservableObject {
    @Published var slots: [String: MealSlot] = [:]   // key: "yyyy-MM-dd-lunch"
    @Published var recipes: [UUID: Recipe] = [:]
    @Published var isLoading = false
    @Published var isReconnecting = false
    @Published var error: String?

    // Members are owned by AppState; this is a local reference updated on load.
    // PlanTabView syncs appState.members → here via .onChange so HouseholdView edits
    // propagate without a DB round-trip.
    @Published var members: [Member] = []

    private let mealPlanService = MealPlanService()
    private let recipeService = RecipeService()
    private let householdService = HouseholdService()
    private var realtimeChannel: RealtimeChannelV2?
    private var householdId: UUID?

    // MARK: - Week navigation

    @Published var weekStart: Date = Date().startOfWeek

    var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    // MARK: - Week header title

    var weekTitle: String {
        let days = weekDays
        guard let first = days.first, let last = days.last else { return "This Week" }
        if Calendar.current.isDate(weekStart, equalTo: Date().startOfWeek, toGranularity: .day) {
            return "This Week"
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let lastF = DateFormatter()
        // Same month: "Jun 23 – 29". Different month: "Jun 30 – Jul 6".
        if Calendar.current.component(.month, from: first) == Calendar.current.component(.month, from: last) {
            lastF.dateFormat = "d"
        } else {
            lastF.dateFormat = "MMM d"
        }
        return "\(f.string(from: first)) – \(lastF.string(from: last))"
    }

    // MARK: - Grocery list

    func weeklyGroceryList() -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        var planLines: [String] = []
        for day in weekDays {
            for mealType in MealType.allCases {
                let key = "\(DateFormatter.isoDate.string(from: day))-\(mealType.rawValue)"
                if let slot = slots[key], let id = slot.recipeId, let recipe = recipes[id] {
                    planLines.append("\(dayFormatter.string(from: day)) \(mealType.shortLabel): \(recipe.emoji) \(recipe.name)")
                }
            }
        }

        var seen = Set<String>()
        var ingredients: [String] = []
        for day in weekDays {
            for mealType in MealType.allCases {
                let key = "\(DateFormatter.isoDate.string(from: day))-\(mealType.rawValue)"
                if let slot = slots[key], let id = slot.recipeId, let recipe = recipes[id] {
                    for ingredient in recipe.ingredients {
                        let normalised = ingredient.trimmingCharacters(in: .whitespaces)
                        guard !normalised.isEmpty else { continue }
                        if seen.insert(normalised.lowercased()).inserted {
                            ingredients.append(normalised)
                        }
                    }
                }
            }
        }

        var text = "📅 \(weekTitle)\n"
        if planLines.isEmpty {
            text += "(nothing planned yet)\n"
        } else {
            text += planLines.joined(separator: "\n") + "\n"
        }
        text += "\n🛒 Groceries\n"
        if ingredients.isEmpty {
            text += "(no ingredients to list)\n"
        } else {
            text += ingredients.map { "• \($0)" }.joined(separator: "\n") + "\n"
        }
        text += "\nSent from Meal Memory"
        return text
    }

    // MARK: - Load

    func load(householdId: UUID) async {
        self.householdId = householdId

        if DemoData.isDemoMode {
            recipes = Dictionary(uniqueKeysWithValues: DemoData.recipes.map { ($0.id, $0) })
            slots   = DemoData.slots(for: weekStart)
            members = DemoData.members
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Fetch concurrently; failures are non-fatal — show what we have.
        async let slotsTask   = mealPlanService.fetchWeek(householdId: householdId, startDate: weekStart)
        async let recipesTask = recipeService.fetchRecipes(householdId: householdId)
        async let membersTask = householdService.fetchMembers(householdId: householdId)

        if let fetched = try? await slotsTask {
            slots = Dictionary(uniqueKeysWithValues: fetched.map { ($0.slotKey, $0) })
        }
        if let fetched = try? await recipesTask {
            recipes = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        }
        if let fetched = try? await membersTask {
            members = fetched
        }

        subscribeRealtime(householdId: householdId)
    }

    func reloadWeek() async {
        guard let householdId else { return }
        await load(householdId: householdId)
    }

    func reloadSlots() async {
        if DemoData.isDemoMode {
            slots = DemoData.slots(for: weekStart)
            return
        }
        guard let id = householdId else { return }
        if let fetched = try? await mealPlanService.fetchWeek(householdId: id, startDate: weekStart) {
            slots = Dictionary(uniqueKeysWithValues: fetched.map { ($0.slotKey, $0) })
        }
    }

    // MARK: - Slot interactions

    func placeRecipe(_ recipeId: UUID, on date: Date, mealType: MealType) async {
        guard let householdId else { return }
        if DemoData.isDemoMode {
            let key = slotKey(date: date, mealType: mealType)
            var slot = slots[key] ?? MealSlot(
                id: UUID(), householdId: householdId,
                slotDate: date, mealType: mealType,
                recipeId: nil, updatedBy: DemoData.userId, updatedAt: Date())
            slot.recipeId = recipeId
            slot.updatedAt = Date()
            slots[key] = slot
            return
        }
        do {
            let updated = try await mealPlanService.upsertSlot(
                householdId: householdId, date: date, mealType: mealType, recipeId: recipeId)
            slots[updated.slotKey] = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func swapSlots(_ slotA: MealSlot, _ slotB: MealSlot) async {
        if DemoData.isDemoMode {
            var a = slotA; var b = slotB
            let tmp = a.recipeId
            a.recipeId = b.recipeId
            b.recipeId = tmp
            a.updatedAt = Date(); b.updatedAt = Date()
            slots[a.slotKey] = a; slots[b.slotKey] = b
            return
        }
        guard let householdId else { return }
        do {
            let (a, b) = try await mealPlanService.swapSlots(householdId: householdId, slotA: slotA, slotB: slotB)
            slots[a.slotKey] = a
            slots[b.slotKey] = b
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearSlot(date: Date, mealType: MealType) async {
        if DemoData.isDemoMode {
            let key = slotKey(date: date, mealType: mealType)
            if var slot = slots[key] {
                slot.recipeId = nil
                slot.updatedAt = Date()
                slots[key] = slot
            }
            return
        }
        guard let householdId else { return }
        do {
            let updated = try await mealPlanService.upsertSlot(
                householdId: householdId, date: date, mealType: mealType, recipeId: nil)
            slots[updated.slotKey] = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Drag-drop helper

    func slot(for date: Date, mealType: MealType) -> MealSlot? {
        slots[slotKey(date: date, mealType: mealType)]
    }

    func recipe(for slot: MealSlot) -> Recipe? {
        slot.recipeId.flatMap { recipes[$0] }
    }

    // Returns dietary restrictions unmet by the recipe, given the supplied member list.
    func dietaryConflicts(for recipe: Recipe, using members: [Member]) -> [String] {
        let allRestrictions = Set(members.flatMap { $0.dietaryRestrictions })
        return allRestrictions.filter { !recipe.safeForTags.contains($0) }.sorted()
    }

    // MARK: - Realtime

    private func subscribeRealtime(householdId: UUID) {
        if let existing = realtimeChannel {
            Task { await existing.unsubscribe() }
        }
        realtimeChannel = mealPlanService.subscribeToWeek(householdId: householdId) { [weak self] updatedSlot in
            Task { @MainActor [weak self] in
                self?.slots[updatedSlot.slotKey] = updatedSlot
            }
        }
    }

    func handleReconnect() async {
        isReconnecting = false
        await reloadWeek()
    }

    // MARK: - Private

    private func slotKey(date: Date, mealType: MealType) -> String {
        "\(DateFormatter.isoDate.string(from: date))-\(mealType.rawValue)"
    }
}

// MARK: - Extensions

extension MealSlot {
    var slotKey: String { "\(DateFormatter.isoDate.string(from: slotDate))-\(mealType.rawValue)" }
}

extension Date {
    var startOfWeek: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2  // Monday
        return cal.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    var isToday: Bool { Calendar.current.isDateInToday(self) }
}
