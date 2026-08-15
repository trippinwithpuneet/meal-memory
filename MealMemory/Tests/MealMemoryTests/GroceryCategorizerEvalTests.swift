import XCTest
@testable import MealMemory

/// Eval for the offline grocery-aisle categorizer (TRI-11).
///
/// This is scored rather than binary: the categorizer is a keyword matcher, so
/// the useful question is "what percentage of a realistic shopping list does it
/// file correctly, and which items does it get wrong" — not "does one lookup
/// work". Misclassifications are printed so they're actionable, and the
/// accuracy floor fails the build if a keyword edit regresses the corpus.
///
/// Labels are what a shopper would expect, NOT what the code currently returns.
/// That's deliberate: a corpus written to match the implementation can only ever
/// score 100% and tells you nothing.
final class GroceryCategorizerEvalTests: XCTestCase {

    /// (ingredient as a user would type it, aisle a shopper would expect)
    private static let corpus: [(String, GroceryAisle)] = [
        // ── Fruit & Vegetables ────────────────────────────────────────────────
        ("2 large tomatoes", .fruitVeg),
        ("cherry tomatoes", .fruitVeg),
        ("1 avocado, sliced", .fruitVeg),
        ("1 red onion, finely chopped", .fruitVeg),
        ("2 shallots", .fruitVeg),
        ("spring onions", .fruitVeg),
        ("4 cloves garlic", .fruitVeg),
        ("1 thumb ginger", .fruitVeg),
        ("1 bell pepper", .fruitVeg),
        ("1 red pepper, sliced", .fruitVeg),
        ("1 head broccoli", .fruitVeg),
        ("baby spinach", .fruitVeg),
        ("romaine lettuce", .fruitVeg),
        ("1 cucumber, diced", .fruitVeg),
        ("2 limes", .fruitVeg),
        ("1 lemon, juiced", .fruitVeg),
        ("1 orange", .fruitVeg),
        ("2 apples", .fruitVeg),
        ("3 bananas", .fruitVeg),
        ("blueberries", .fruitVeg),
        ("2 carrots, grated", .fruitVeg),
        ("2 sticks celery", .fruitVeg),
        ("500g potatoes", .fruitVeg),
        ("1 sweet potato", .fruitVeg),
        ("250g mushrooms", .fruitVeg),
        ("1 zucchini", .fruitVeg),
        ("1 courgette", .fruitVeg),
        ("corn on the cob", .fruitVeg),
        ("fresh cilantro", .fruitVeg),
        ("flat-leaf parsley", .fruitVeg),
        ("fresh basil", .fruitVeg),
        ("kale", .fruitVeg),
        ("1/2 cabbage", .fruitVeg),
        ("1 cauliflower", .fruitVeg),
        ("asparagus spears", .fruitVeg),
        ("2 leeks", .fruitVeg),
        ("beetroot", .fruitVeg),
        ("frozen peas", .fruitVeg),
        ("1 green chilli", .fruitVeg),

        // ── Dry Pantry ────────────────────────────────────────────────────────
        ("basmati rice", .dryPantry),
        ("500g pasta", .dryPantry),
        ("spaghetti", .dryPantry),
        ("egg noodles", .dryPantry),
        ("plain flour", .dryPantry),
        ("caster sugar", .dryPantry),
        ("olive oil", .dryPantry),
        ("1 tsp salt", .dryPantry),
        ("black pepper", .dryPantry),
        ("salt and pepper to taste", .dryPantry),
        ("1 can chickpeas, drained", .dryPantry),
        ("red lentils", .dryPantry),
        ("1 can black beans", .dryPantry),
        ("kidney beans", .dryPantry),
        ("quinoa", .dryPantry),
        ("rolled oats", .dryPantry),
        ("granola", .dryPantry),
        ("tahini", .dryPantry),
        ("2 tbsp soy sauce", .dryPantry),
        ("white wine vinegar", .dryPantry),
        ("vegetable stock", .dryPantry),
        ("1 tsp cumin", .dryPantry),
        ("smoked paprika", .dryPantry),
        ("turmeric", .dryPantry),
        ("cinnamon", .dryPantry),
        ("baking powder", .dryPantry),
        ("2 tbsp honey", .dryPantry),
        ("maple syrup", .dryPantry),
        ("chia seeds", .dryPantry),
        ("flaked almonds", .dryPantry),
        ("tomato paste", .dryPantry),
        ("dijon mustard", .dryPantry),
        ("mayonnaise", .dryPantry),
        ("ketchup", .dryPantry),
        ("sesame oil", .dryPantry),
        ("couscous", .dryPantry),
        ("tinned tomatoes", .dryPantry),
        ("peanut butter", .dryPantry),
        ("1 can coconut milk", .dryPantry),
        ("sriracha", .dryPantry),

        // ── Dairy / Bread & Eggs ──────────────────────────────────────────────
        ("500ml whole milk", .dairyBreadEggs),
        ("unsalted butter", .dairyBreadEggs),
        ("cheddar cheese", .dairyBreadEggs),
        ("200g paneer", .dairyBreadEggs),
        ("greek yogurt", .dairyBreadEggs),
        ("double cream", .dairyBreadEggs),
        ("sourdough loaf", .dairyBreadEggs),
        ("burger buns", .dairyBreadEggs),
        ("flour tortillas", .dairyBreadEggs),
        ("naan bread", .dairyBreadEggs),
        ("pita bread", .dairyBreadEggs),
        ("mozzarella", .dairyBreadEggs),
        ("grated parmesan", .dairyBreadEggs),
        ("feta cheese", .dairyBreadEggs),
        ("2 bagels", .dairyBreadEggs),
        ("6 eggs", .dairyBreadEggs),
        ("halloumi", .dairyBreadEggs),

        // ── Meat & Fish (the protein aisle — tofu/tempeh belong here too) ──────
        ("2 chicken breasts", .meatFish),
        ("4 chicken thighs, bone-in", .meatFish),
        ("500g beef mince", .meatFish),
        ("pork chops", .meatFish),
        ("streaky bacon", .meatFish),
        ("6 sausages", .meatFish),
        ("turkey mince", .meatFish),
        ("lamb shoulder", .meatFish),
        ("sliced ham", .meatFish),
        ("ground beef", .meatFish),
        ("sirloin steak", .meatFish),
        ("1 can tuna", .meatFish),
        ("salmon fillet", .meatFish),
        ("king prawns", .meatFish),
        ("cod loin", .meatFish),
        ("400g firm tofu", .meatFish),
        ("tempeh", .meatFish),
    ]

    /// Accuracy floor. The categorizer is intentionally a simple offline keyword
    /// matcher (an LLM fallback is a documented follow-up), so this is a
    /// regression guard, not a claim that 85% is good enough long-term.
    private static let accuracyFloor = 0.85

    func testAisleAccuracyAcrossRealisticShoppingList() {
        var correct = 0
        var misses: [(item: String, expected: GroceryAisle, got: GroceryAisle)] = []
        var perAisleTotal: [GroceryAisle: Int] = [:]
        var perAisleCorrect: [GroceryAisle: Int] = [:]

        for (item, expected) in Self.corpus {
            let got = GroceryCategorizer.aisle(for: item)
            perAisleTotal[expected, default: 0] += 1
            if got == expected {
                correct += 1
                perAisleCorrect[expected, default: 0] += 1
            } else {
                misses.append((item, expected, got))
            }
        }

        let accuracy = Double(correct) / Double(Self.corpus.count)

        print("\n──────────────────────────────────────────────────────────────")
        print("Grocery aisle categorizer eval — \(Self.corpus.count) labeled items")
        print("──────────────────────────────────────────────────────────────")
        for aisle in GroceryAisle.allCases {
            guard let total = perAisleTotal[aisle], total > 0 else { continue }
            let hit = perAisleCorrect[aisle] ?? 0
            let pct = String(format: "%.1f%%", Double(hit) / Double(total) * 100)
            print("  \(aisle.title.padding(toLength: 22, withPad: " ", startingAt: 0)) \(hit)/\(total)  \(pct)")
        }
        print(String(format: "\n  Overall accuracy: %.1f%% (floor %.0f%%)",
                     accuracy * 100, Self.accuracyFloor * 100))
        if !misses.isEmpty {
            print("\n  Misclassified (\(misses.count)):")
            for m in misses {
                print("    \"\(m.item)\" → \(m.got.title), expected \(m.expected.title)")
            }
        }
        print("──────────────────────────────────────────────────────────────\n")

        XCTAssertGreaterThanOrEqual(
            accuracy, Self.accuracyFloor,
            "Aisle accuracy \(accuracy) fell below the \(Self.accuracyFloor) floor. See the misclassification list above."
        )
    }

    // MARK: - Documented priority-order behaviour
    //
    // These encode decisions the keyword order exists to enforce. They are
    // binary on purpose — a regression here is a bug, not a score drop.

    func testCannedLegumesFileUnderPantryNotProduce() {
        // Regression: commit 20c79d1. "bean"/"pea" substrings used to pull canned
        // legumes into produce because fruitVeg was checked first.
        XCTAssertEqual(GroceryCategorizer.aisle(for: "1 can chickpeas"), .dryPantry)
        XCTAssertEqual(GroceryCategorizer.aisle(for: "black beans"), .dryPantry)
        XCTAssertEqual(GroceryCategorizer.aisle(for: "red lentils"), .dryPantry)
    }

    func testFreshPeppersStillReachProduce() {
        XCTAssertEqual(GroceryCategorizer.aisle(for: "1 bell pepper"), .fruitVeg)
        XCTAssertEqual(GroceryCategorizer.aisle(for: "green pepper"), .fruitVeg)
    }

    func testSeasoningPepperGoesToPantry() {
        XCTAssertEqual(GroceryCategorizer.aisle(for: "salt and pepper"), .dryPantry)
        XCTAssertEqual(GroceryCategorizer.aisle(for: "black pepper"), .dryPantry)
    }

    func testCategorizerIsCaseInsensitive() {
        XCTAssertEqual(GroceryCategorizer.aisle(for: "CHICKEN THIGHS"), .meatFish)
        XCTAssertEqual(GroceryCategorizer.aisle(for: "Basmati Rice"), .dryPantry)
    }

    func testUnknownIngredientFallsToOther() {
        XCTAssertEqual(GroceryCategorizer.aisle(for: "zzzznotafood"), .other)
        XCTAssertEqual(GroceryCategorizer.aisle(for: ""), .other)
    }

    func testEveryAisleHasTitleAndEmoji() {
        for aisle in GroceryAisle.allCases {
            XCTAssertFalse(aisle.title.isEmpty, "\(aisle) has no title")
            XCTAssertFalse(aisle.emoji.isEmpty, "\(aisle) has no emoji")
        }
    }

    func testAisleDisplayOrderIsAStoreWalk() {
        // Order backs the section order in the grocery list — produce first,
        // chilled/meat last, "Other" as the catch-all at the bottom.
        XCTAssertEqual(GroceryAisle.allCases.map(\.self),
                       [.fruitVeg, .dryPantry, .dairyBreadEggs, .meatFish, .other])
    }
}
