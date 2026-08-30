import XCTest
@testable import MealMemory

/// Evals for the week-plan logic that backs the Plan tab, the share card
/// (TRI-6), and the grocery export (TRI-11).
///
/// Everything here is offline and deterministic — no Supabase, no realtime. The
/// view model's published state is populated directly so the pure functions
/// over it can be graded on their own.
@MainActor
final class MealPlanViewModelTests: XCTestCase {

    // MARK: - Fixtures

    private static let householdId = UUID()
    private static let userId = UUID()

    private func makeRecipe(
        _ name: String,
        emoji: String = "🍽",
        ingredients: [String] = [],
        safeFor: [String] = []
    ) -> Recipe {
        Recipe(
            id: UUID(),
            householdId: Self.householdId,
            name: name,
            emoji: emoji,
            ingredients: ingredients,
            steps: [],
            safeForTags: safeFor,
            archived: false,
            createdBy: Self.userId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeSlot(date: Date, meal: MealType, recipeId: UUID?) -> MealSlot {
        MealSlot(
            id: UUID(),
            householdId: Self.householdId,
            slotDate: date,
            mealType: meal,
            recipeId: recipeId,
            updatedBy: Self.userId,
            updatedAt: Date()
        )
    }

    /// A fixed Monday so week arithmetic never depends on when the suite runs.
    private func monday(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func place(_ vm: MealPlanViewModel, _ recipe: Recipe, day: Int, meal: MealType) {
        let date = Calendar.current.date(byAdding: .day, value: day, to: vm.weekStart)!
        let slot = makeSlot(date: date, meal: meal, recipeId: recipe.id)
        vm.recipes[recipe.id] = recipe
        vm.slots[slot.slotKey] = slot
    }

    // MARK: - Week boundaries

    func testStartOfWeekIsMonday() {
        // The app plans Mon–Sun; a Sunday-start week would shift every slot.
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2

        // 2026-08-15 is a Saturday; its week starts Monday 2026-08-10.
        let saturday = cal.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let start = saturday.startOfWeek
        XCTAssertEqual(cal.component(.weekday, from: start), 2, "startOfWeek must land on a Monday")
        XCTAssertEqual(cal.component(.day, from: start), 10)
    }

    func testStartOfWeekOnAMondayIsThatSameDay() {
        let mon = monday(2026, 8, 10)
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        XCTAssertEqual(cal.component(.day, from: mon.startOfWeek), 10)
    }

    func testStartOfWeekOnASundayStaysInTheWeekJustEnding() {
        // Sunday 2026-08-16 belongs to the week that began Monday the 10th.
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let sunday = cal.date(from: DateComponents(year: 2026, month: 8, day: 16))!
        XCTAssertEqual(cal.component(.day, from: sunday.startOfWeek), 10)
    }

    func testWeekDaysReturnsSevenConsecutiveDays() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        let days = vm.weekDays
        XCTAssertEqual(days.count, 7)
        for (i, day) in days.enumerated() {
            let expected = Calendar.current.date(byAdding: .day, value: i, to: vm.weekStart)!
            XCTAssertEqual(Calendar.current.compare(day, to: expected, toGranularity: .day), .orderedSame)
        }
    }

    // MARK: - Week title

    func testWeekTitleSaysThisWeekForTheCurrentWeek() {
        let vm = MealPlanViewModel()
        vm.weekStart = Date().startOfWeek
        XCTAssertEqual(vm.weekTitle, "This Week")
    }

    func testWeekTitleWithinOneMonthOmitsTheSecondMonthName() {
        // "Jun 23 – 29" — the trailing half is a bare day number.
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 6, 22)
        let title = vm.weekTitle
        XCTAssertTrue(title.contains("–"), "expected an en-dash range, got \(title)")
        let tail = title.components(separatedBy: "–")[1].trimmingCharacters(in: .whitespaces)
        XCTAssertNil(tail.rangeOfCharacter(from: .letters),
                     "same-month range should end in a bare day number, got \(title)")
    }

    func testWeekTitleSpanningTwoMonthsNamesBothMonths() {
        // "Jun 29 – Jul 5"
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 6, 29)
        let title = vm.weekTitle
        let tail = title.components(separatedBy: "–")[1].trimmingCharacters(in: .whitespaces)
        XCTAssertNotNil(tail.rangeOfCharacter(from: .letters),
                        "cross-month range must repeat the month, got \(title)")
    }

    // MARK: - weeklyPlan

    func testWeeklyPlanOnlyIncludesDaysThatHaveMeals() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("Burrito Bowl"), day: 0, meal: .dinner)
        place(vm, makeRecipe("Egg Sandwich"), day: 3, meal: .breakfast)

        let plan = vm.weeklyPlan()
        XCTAssertEqual(plan.count, 2, "empty days must be dropped, not rendered blank")
    }

    func testWeeklyPlanOrdersMealsBreakfastLunchDinner() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        // Deliberately inserted out of order.
        place(vm, makeRecipe("Dinner dish"), day: 0, meal: .dinner)
        place(vm, makeRecipe("Breakfast dish"), day: 0, meal: .breakfast)
        place(vm, makeRecipe("Lunch dish"), day: 0, meal: .lunch)

        let meals = vm.weeklyPlan().first!.meals
        XCTAssertEqual(meals.map(\.type), [.breakfast, .lunch, .dinner])
    }

    func testWeeklyPlanSkipsSlotsWhoseRecipeIsMissing() {
        // A slot can outlive its recipe (archived/deleted elsewhere, realtime lag).
        // It must not crash or render an empty card.
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        let orphan = makeSlot(date: vm.weekStart, meal: .lunch, recipeId: UUID())
        vm.slots[orphan.slotKey] = orphan

        XCTAssertTrue(vm.weeklyPlan().isEmpty)
    }

    func testWeeklyPlanIgnoresClearedSlots() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        let cleared = makeSlot(date: vm.weekStart, meal: .lunch, recipeId: nil)
        vm.slots[cleared.slotKey] = cleared

        XCTAssertTrue(vm.weeklyPlan().isEmpty)
    }

    // MARK: - Share text

    func testWeeklyPlanTextIncludesEveryPlannedDish() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("Burrito Bowl", emoji: "🌯"), day: 0, meal: .dinner)
        place(vm, makeRecipe("Egg Sandwich", emoji: "🥪"), day: 2, meal: .breakfast)

        let text = vm.weeklyPlanText()
        XCTAssertTrue(text.contains("Burrito Bowl"))
        XCTAssertTrue(text.contains("Egg Sandwich"))
        XCTAssertTrue(text.contains("🌯"))
        XCTAssertTrue(text.contains("Sent from Meal Memory"))
    }

    func testWeeklyPlanTextHandlesAnEmptyWeekGracefully() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        let text = vm.weeklyPlanText()
        XCTAssertTrue(text.contains("nothing planned yet"),
                      "an empty week must share as a readable message, not a blank card")
    }

    func testWeeklyPlanTextExcludesGroceries() {
        // Deliberate product split: the plan share (TRI-6) and the grocery list
        // (TRI-11) are separate features.
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("Burrito Bowl", ingredients: ["rice", "beans"]), day: 0, meal: .dinner)

        let text = vm.weeklyPlanText()
        XCTAssertFalse(text.contains("Groceries"))
        XCTAssertFalse(text.contains("rice"))
    }

    // MARK: - Grocery list

    func testGroceryListDedupesCaseInsensitivelyAndTrims() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("A", ingredients: ["Tomato", "Rice"]), day: 0, meal: .lunch)
        place(vm, makeRecipe("B", ingredients: ["tomato ", "  TOMATO", "Rice"]), day: 1, meal: .lunch)

        let text = vm.weeklyGroceryList()
        let tomatoLines = text
            .components(separatedBy: "\n")
            .filter { $0.lowercased().contains("tomato") && $0.hasPrefix("•") }
        XCTAssertEqual(tomatoLines.count, 1, "the same ingredient must appear once, got \(tomatoLines)")
    }

    func testGroceryListKeepsFirstSeenCasingForReadability() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("A", ingredients: ["Basmati Rice"]), day: 0, meal: .lunch)
        place(vm, makeRecipe("B", ingredients: ["basmati rice"]), day: 1, meal: .lunch)

        XCTAssertTrue(vm.weeklyGroceryList().contains("• Basmati Rice"))
    }

    func testGroceryListSkipsBlankIngredients() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        place(vm, makeRecipe("A", ingredients: ["", "   ", "Rice"]), day: 0, meal: .lunch)

        let bullets = vm.weeklyGroceryList()
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("•") }
        XCTAssertEqual(bullets.count, 1)
    }

    func testGroceryListHandlesAnEmptyWeek() {
        let vm = MealPlanViewModel()
        vm.weekStart = monday(2026, 8, 10)
        XCTAssertTrue(vm.weeklyGroceryList().contains("no ingredients to list"))
    }

    // MARK: - Slot keys

    func testSlotKeyIsStableAcrossIdenticalDateAndMeal() {
        let date = monday(2026, 8, 10)
        let a = makeSlot(date: date, meal: .lunch, recipeId: nil)
        let b = makeSlot(date: date, meal: .lunch, recipeId: UUID())
        XCTAssertEqual(a.slotKey, b.slotKey, "the key identifies the cell, not the row")
    }

    func testSlotKeyDistinguishesMealTypesOnTheSameDay() {
        let date = monday(2026, 8, 10)
        let keys = Set(MealType.allCases.map { makeSlot(date: date, meal: $0, recipeId: nil).slotKey })
        XCTAssertEqual(keys.count, 3)
    }

    // MARK: - Dietary conflicts

    func testDietaryConflictsReportsRestrictionsTheRecipeDoesNotCover() {
        let vm = MealPlanViewModel()
        let members = [
            Member(id: UUID(), householdId: Self.householdId, userId: UUID(),
                   displayName: "Alex", dietaryRestrictions: ["Gluten-free", "No milk"],
                   apnsDeviceTokens: [], joinedAt: Date()),
            Member(id: UUID(), householdId: Self.householdId, userId: UUID(),
                   displayName: "Jordan", dietaryRestrictions: [],
                   apnsDeviceTokens: [], joinedAt: Date()),
        ]
        let pancakes = makeRecipe("Pancakes", safeFor: [])
        XCTAssertEqual(vm.dietaryConflicts(for: pancakes, using: members), ["Gluten-free", "No milk"])

        let safeBowl = makeRecipe("Burrito Bowl", safeFor: ["Gluten-free", "No milk"])
        XCTAssertTrue(vm.dietaryConflicts(for: safeBowl, using: members).isEmpty)

        let partial = makeRecipe("Yogurt Bowl", safeFor: ["Gluten-free"])
        XCTAssertEqual(vm.dietaryConflicts(for: partial, using: members), ["No milk"])
    }

    func testDietaryConflictsAreDedupedAcrossMembers() {
        let vm = MealPlanViewModel()
        let members = (0..<3).map { _ in
            Member(id: UUID(), householdId: Self.householdId, userId: UUID(),
                   displayName: "M", dietaryRestrictions: ["Gluten-free"],
                   apnsDeviceTokens: [], joinedAt: Date())
        }
        XCTAssertEqual(vm.dietaryConflicts(for: makeRecipe("Toast"), using: members), ["Gluten-free"])
    }

    func testNoMembersMeansNoConflicts() {
        let vm = MealPlanViewModel()
        XCTAssertTrue(vm.dietaryConflicts(for: makeRecipe("Anything"), using: []).isEmpty)
    }
}
