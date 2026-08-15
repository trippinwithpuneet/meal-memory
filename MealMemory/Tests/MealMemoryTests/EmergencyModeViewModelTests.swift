import XCTest
@testable import MealMemory

/// Evals for Fridge Raid ("What can I cook?") — the ingredient-matching search.
///
/// Ranking quality is the product here, so these grade both the mechanics
/// (dedupe, clearing input) and the ranking itself: the best-matching recipe
/// must come first, and a recipe you genuinely can't cook must not surface.
@MainActor
final class EmergencyModeViewModelTests: XCTestCase {

    private static let householdId = UUID()

    private func recipe(_ name: String, _ ingredients: [String]) -> Recipe {
        Recipe(
            id: UUID(), householdId: Self.householdId, name: name, emoji: "🍽",
            ingredients: ingredients, steps: [], safeForTags: [],
            archived: false, createdBy: UUID(), createdAt: Date(), updatedAt: Date()
        )
    }

    private func makeVM(_ recipes: [Recipe]) -> EmergencyModeViewModel {
        let vm = EmergencyModeViewModel()
        vm.allRecipes = recipes
        return vm
    }

    // MARK: - Ingredient chips

    func testAddIngredientTrimsWhitespaceAndClearsTheInput() {
        let vm = makeVM([])
        vm.ingredientInput = "  eggs  "
        vm.addIngredient("  eggs  ")
        XCTAssertEqual(vm.typedIngredients, ["eggs"])
        XCTAssertEqual(vm.ingredientInput, "", "the field must reset so the next chip can be typed")
    }

    func testAddIngredientIgnoresEmptyAndWhitespaceOnlyInput() {
        let vm = makeVM([])
        vm.addIngredient("")
        vm.addIngredient("   ")
        XCTAssertTrue(vm.typedIngredients.isEmpty)
    }

    func testAddIngredientDedupesCaseInsensitively() {
        let vm = makeVM([])
        vm.addIngredient("Eggs")
        vm.addIngredient("eggs")
        vm.addIngredient("EGGS")
        XCTAssertEqual(vm.typedIngredients, ["Eggs"], "one chip per ingredient, first casing wins")
    }

    func testRemoveIngredientReRunsTheSearch() {
        let vm = makeVM([recipe("Omelette", ["eggs", "butter"])])
        vm.addIngredient("eggs")
        XCTAssertEqual(vm.results.count, 1)

        vm.removeIngredient("eggs")
        XCTAssertTrue(vm.typedIngredients.isEmpty)
        XCTAssertTrue(vm.results.isEmpty, "clearing the last chip must clear the results")
    }

    func testSearchWithNoIngredientsReturnsNothing() {
        let vm = makeVM([recipe("Omelette", ["eggs"])])
        vm.search()
        XCTAssertTrue(vm.results.isEmpty, "an empty fridge shouldn't recommend everything")
    }

    // MARK: - Matching and scoring

    func testMatchCountAndScoreReflectHowMuchOfTheRecipeYouHave() {
        let vm = makeVM([recipe("Stir Fry", ["tofu", "broccoli", "soy sauce", "garlic"])])
        vm.addIngredient("tofu")
        vm.addIngredient("broccoli")

        let result = vm.results.first!
        XCTAssertEqual(result.matchCount, 2)
        XCTAssertEqual(result.matchScore, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.matchPercent, 50)
    }

    func testMissingIngredientsListsExactlyWhatYouStillNeed() {
        let vm = makeVM([recipe("Stir Fry", ["tofu", "broccoli", "soy sauce"])])
        vm.addIngredient("tofu")

        let result = vm.results.first!
        XCTAssertEqual(Set(result.missingIngredients), ["broccoli", "soy sauce"])
        XCTAssertEqual(result.matchingIngredients, ["tofu"])
    }

    func testRecipesWithNoMatchingIngredientAreExcluded() {
        let vm = makeVM([
            recipe("Omelette", ["eggs", "butter"]),
            recipe("Fruit Salad", ["apple", "banana"]),
        ])
        vm.addIngredient("eggs")

        XCTAssertEqual(vm.results.count, 1)
        XCTAssertEqual(vm.results.first?.recipe.name, "Omelette")
    }

    func testResultsAreRankedByHowCompleteTheMatchIs() {
        let vm = makeVM([
            recipe("Big Curry", ["onion", "garlic", "tomato", "cream", "chicken", "spices"]), // 1/6
            recipe("Garlic Toast", ["bread", "garlic"]),                                      // 1/2
            recipe("Garlic Oil", ["garlic"]),                                                 // 1/1
        ])
        vm.addIngredient("garlic")

        XCTAssertEqual(vm.results.map(\.recipe.name), ["Garlic Oil", "Garlic Toast", "Big Curry"],
                       "the recipe you can most nearly cook tonight must rank first")
    }

    func testMatchingIsCaseInsensitive() {
        let vm = makeVM([recipe("Omelette", ["Eggs", "Butter"])])
        vm.addIngredient("EGGS")
        XCTAssertEqual(vm.results.count, 1)
    }

    func testPartialWordsMatchSoQuantitiesInIngredientsStillWork() {
        // Recipes store "2 large eggs", the user types "eggs".
        let vm = makeVM([recipe("Omelette", ["2 large eggs", "1 tbsp butter"])])
        vm.addIngredient("eggs")
        XCTAssertEqual(vm.results.first?.matchCount, 1)
    }

    func testEmptyIngredientListRecipeIsNeverRecommended() {
        // A recipe saved without ingredients (manual entry, or a lossy import)
        // would otherwise divide by zero in matchScore.
        let vm = makeVM([recipe("Mystery Dish", [])])
        vm.addIngredient("eggs")
        XCTAssertTrue(vm.results.isEmpty)
    }

    // MARK: - Known limitation of substring matching
    //
    // Matching is bidirectional substring containment, so short words match
    // inside longer unrelated ones. This is documented rather than asserted as
    // correct: it's the current design, and these tests exist so that a future
    // move to token matching is a deliberate, visible change.

    func testSubstringMatchingProducesFalsePositives() {
        let vm = makeVM([recipe("Eggplant Parm", ["eggplant", "tomato", "mozzarella"])])
        vm.addIngredient("egg")

        XCTAssertEqual(vm.results.count, 1,
                       "typing 'egg' currently matches 'eggplant' — token matching would fix this")
        XCTAssertEqual(vm.results.first?.matchingIngredients, ["eggplant"])
    }

    func testSubstringMatchingIsSymmetric() {
        // Typed term longer than the stored ingredient also matches.
        let vm = makeVM([recipe("Rice Bowl", ["rice"])])
        vm.addIngredient("brown rice")
        XCTAssertEqual(vm.results.count, 1)
    }
}
