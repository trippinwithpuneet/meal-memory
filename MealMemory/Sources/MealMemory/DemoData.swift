import Foundation

// Toggle this to true to run the app with pre-loaded fake data on the simulator.
// No network calls are made in demo mode — safe to use on iOS 26.5 simulator.
enum DemoData {
    static var isDemoMode: Bool {
        // True by default (first install). Flips to false when user taps "Start fresh".
        UserDefaults.standard.object(forKey: "demo_mode_active") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "demo_mode_active")
    }

    static let householdId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let userId      = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // MARK: - Members
    //
    // Two members with one common restriction so the demo still shows how the
    // plan flags meals that don't work for everyone. Alex is gluten-free + no
    // milk; Jordan eats everything.

    static let members: [Member] = [
        Member(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
            householdId: householdId,
            userId: userId,
            displayName: "Alex",
            dietaryRestrictions: ["Gluten-free", "No milk"],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
        Member(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            householdId: householdId,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            displayName: "Jordan",
            dietaryRestrictions: [],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
    ]

    // MARK: - Recipes
    //
    // Western-familiar demo set. Recipe index reference (used in slots below):
    //   0  Burrito Bowl              — both safe ✅
    //   1  Chickpea Salad            — both safe ✅
    //   2  Quinoa Beetroot Bowl      — both safe ✅
    //   3  Spaghetti Aglio e Olio    — Alex conflict (gluten) ❌
    //   4  Egg Sandwich              — Alex conflict (gluten) ❌
    //   5  Sheet-Pan Chicken & Veg   — both safe ✅
    //   6  Greek Yogurt Berry Bowl   — Alex conflict (milk) ❌
    //   7  Pancakes                  — Alex conflict (gluten + milk) ❌
    //   8  Tofu Stir Fry             — both safe ✅
    //   9  Tuna & Egg Salad          — both safe ✅

    static let recipes: [Recipe] = [

        // ── Both safe ──────────────────────────────────────────────────────────

        make(id: 1, name: "Burrito Bowl", emoji: "🌯", prepTime: 30, nightBefore: true,
             ingredients: ["1 cup rice",
                           "1 can black beans, drained",
                           "1 cup frozen corn",
                           "1 ripe avocado",
                           "1 cup cherry tomatoes",
                           "2 limes",
                           "small bunch cilantro",
                           "1 tsp cumin, salt, olive oil"],
             steps: ["Cook rice with cumin and salt until fluffy",
                     "Warm black beans and corn in a pan for 3 min",
                     "Halve tomatoes, dice avocado, roughly chop cilantro",
                     "Assemble bowls: rice base, then beans, corn",
                     "Top with avocado, tomatoes, cilantro and a good squeeze of lime"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        make(id: 2, name: "Chickpea Salad", emoji: "🥗", prepTime: 15,
             ingredients: ["1 can chickpeas, drained",
                           "1 orange, segmented",
                           "1 cucumber, diced",
                           "½ red onion, finely diced",
                           "3 tbsp mayo",
                           "1 lemon, juiced",
                           "small bunch parsley, chili flakes"],
             steps: ["Drain and rinse chickpeas; dice cucumber; segment orange",
                     "Whisk mayo with lemon juice, salt and pepper",
                     "Toss chickpeas, cucumber and onion with dressing",
                     "Top with orange segments, parsley and a pinch of chili flakes"],
             safeFor: ["Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        make(id: 3, name: "Quinoa Beetroot Bowl", emoji: "🥣", prepTime: 35,
             ingredients: ["1 cup quinoa",
                           "250g pre-cooked beets",
                           "2 handfuls baby spinach",
                           "3 tbsp tahini",
                           "1 lemon, juiced",
                           "1 garlic clove, minced",
                           "2 tbsp pumpkin seeds, toasted"],
             steps: ["Rinse quinoa; cook in 2 cups water for 15 min until fluffy, then rest 5 min",
                     "Slice beets into wedges",
                     "Whisk tahini with lemon, garlic and 2 tbsp water until smooth",
                     "Assemble: quinoa, spinach, beets; drizzle dressing, scatter seeds"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        // ── Alex conflict: gluten ──────────────────────────────────────────────

        make(id: 4, name: "Spaghetti Aglio e Olio", emoji: "🍝", prepTime: 25,
             ingredients: ["300g spaghetti",
                           "6 garlic cloves, thinly sliced",
                           "4 tbsp olive oil",
                           "1 tsp red chili flakes",
                           "small bunch parsley, chopped",
                           "salt",
                           "reserved pasta water"],
             steps: ["Boil spaghetti in well-salted water until al dente; reserve 1 cup pasta water",
                     "Gently sauté garlic in olive oil over low heat until golden — don't let it burn",
                     "Add chili flakes, then drained pasta and a splash of pasta water",
                     "Toss vigorously until silky; finish with parsley and season to taste"],
             safeFor: ["Vegan", "Vegetarian", "No milk", "Dairy-free"]),

        make(id: 5, name: "Egg Sandwich", emoji: "🥪", prepTime: 15,
             ingredients: ["4 slices sourdough bread",
                           "3 eggs",
                           "2 tbsp mayo",
                           "1 tsp dijon mustard",
                           "4 lettuce leaves",
                           "6 cherry tomatoes, sliced",
                           "salt and pepper"],
             steps: ["Hard boil eggs for 10 min; cool under cold water and chop roughly",
                     "Mix chopped eggs with mayo, mustard, salt and pepper",
                     "Toast bread; layer with lettuce, egg mix and sliced tomatoes"],
             safeFor: ["Vegetarian", "No milk", "Dairy-free"]),

        // ── Both safe ──────────────────────────────────────────────────────────

        make(id: 6, name: "Sheet-Pan Chicken & Veg", emoji: "🍗", prepTime: 40, nightBefore: false,
             ingredients: ["4 chicken thighs",
                           "1 lb baby potatoes, halved",
                           "2 bell peppers, chunked",
                           "1 red onion, wedged",
                           "3 tbsp olive oil",
                           "2 tsp paprika",
                           "1 tsp garlic powder",
                           "salt, pepper, lemon"],
             steps: ["Heat oven to 425°F (220°C)",
                     "Toss potatoes, peppers and onion with 2 tbsp oil, paprika, garlic powder, salt",
                     "Nestle chicken among the veg; rub with remaining oil and season",
                     "Roast 35–40 min until chicken is cooked and potatoes are golden; squeeze lemon over"],
             safeFor: ["Gluten-free", "No milk", "Dairy-free"]),

        // ── Alex conflict: milk ────────────────────────────────────────────────

        make(id: 7, name: "Greek Yogurt Berry Bowl", emoji: "🍓", prepTime: 10,
             ingredients: ["1½ cups Greek yogurt",
                           "1 cup mixed berries",
                           "2 tbsp honey",
                           "¼ cup granola",
                           "1 tbsp chia seeds",
                           "handful sliced almonds"],
             steps: ["Spoon yogurt into two bowls",
                     "Top with berries, granola, chia seeds and almonds",
                     "Drizzle with honey and serve"],
             safeFor: ["Vegetarian", "Gluten-free"]),

        // ── Alex conflict: gluten + milk ───────────────────────────────────────

        make(id: 8, name: "Pancakes", emoji: "🥞", prepTime: 20,
             ingredients: ["1 cup all-purpose flour",
                           "1 tbsp sugar",
                           "1 tsp baking powder",
                           "pinch of salt",
                           "1 egg",
                           "¾ cup milk",
                           "2 tbsp melted butter",
                           "maple syrup to serve"],
             steps: ["Whisk flour, sugar, baking powder and salt in a bowl",
                     "Whisk egg, milk and melted butter; pour into dry ingredients and mix until just combined — lumps are fine",
                     "Cook on a medium pan, 2 min per side until bubbles form and edges look set",
                     "Serve warm with maple syrup"],
             safeFor: ["Vegetarian"]),

        // ── Both safe ──────────────────────────────────────────────────────────

        make(id: 9, name: "Tofu Stir Fry", emoji: "🍱", prepTime: 30,
             ingredients: ["300g firm tofu",
                           "1 red bell pepper, sliced",
                           "1 head broccoli, cut into florets",
                           "1 cup snap peas",
                           "3 tbsp tamari (GF soy sauce)",
                           "2 tsp sesame oil",
                           "3 garlic cloves, minced",
                           "1 tsp grated ginger",
                           "cooked rice to serve"],
             steps: ["Press tofu 20 min; cube and pan-fry in oil until golden on all sides",
                     "Stir fry broccoli and pepper in sesame oil with garlic and ginger for 3 min",
                     "Add snap peas and tofu; pour over tamari and toss well for 2 min",
                     "Serve over rice with a drizzle of sesame oil"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        make(id: 10, name: "Tuna & Egg Salad", emoji: "🐟", prepTime: 20,
             ingredients: ["1 can tuna in spring water, drained",
                           "3 eggs, hard boiled",
                           "1 apple, finely diced",
                           "2 celery stalks, sliced",
                           "3 tbsp mayo",
                           "1 tsp dijon mustard",
                           "1 lemon, juiced",
                           "mixed greens to serve"],
             steps: ["Hard boil eggs; cool, peel and chop; drain tuna",
                     "Dice apple small; slice celery",
                     "Mix tuna, eggs, apple and celery with mayo, mustard and lemon juice; season well",
                     "Serve on a bed of mixed greens"],
             safeFor: ["Gluten-free", "No milk", "Dairy-free"]),
    ]

    // MARK: - Slots (populated relative to current week start)

    static func slots(for weekStart: Date) -> [String: MealSlot] {
        let cal = Calendar(identifier: .gregorian)
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: weekStart)!
        }

        let r = recipes
        let assignments: [(offset: Int, meal: MealType, recipeIndex: Int)] = [
            (0, .breakfast, 6),   // Mon breakfast: Greek Yogurt Berry Bowl ❌ Alex (milk)
            (0, .lunch,     1),   // Mon lunch:     Chickpea Salad ✅ both
            (0, .dinner,    5),   // Mon dinner:    Sheet-Pan Chicken & Veg ✅ both
            (1, .breakfast, 7),   // Tue breakfast: Pancakes ❌ Alex (gluten + milk)
            (1, .lunch,     2),   // Tue lunch:     Quinoa Beetroot Bowl ✅ both
            (1, .dinner,    3),   // Tue dinner:    Spaghetti Aglio e Olio ❌ Alex (gluten)
            (2, .lunch,     0),   // Wed lunch:     Burrito Bowl ✅ both
            (2, .dinner,    8),   // Wed dinner:    Tofu Stir Fry ✅ both
            (3, .lunch,     9),   // Thu lunch:     Tuna & Egg Salad ✅ both
            (3, .dinner,    5),   // Thu dinner:    Sheet-Pan Chicken & Veg ✅ both
            (4, .breakfast, 4),   // Fri breakfast: Egg Sandwich ❌ Alex (gluten)
            (4, .dinner,    0),   // Fri dinner:    Burrito Bowl ✅ both
        ]

        var result: [String: MealSlot] = [:]
        for (idx, (offset, meal, recipeIdx)) in assignments.enumerated() {
            let date = day(offset)
            let slot = MealSlot(
                id: UUID(uuidString: "00000000-0000-0000-0002-\(String(format: "%012d", idx))")!,
                householdId: householdId,
                slotDate: date,
                mealType: meal,
                recipeId: r[recipeIdx].id,
                updatedBy: userId,
                updatedAt: Date()
            )
            result[slot.slotKey] = slot
        }
        return result
    }

    // MARK: - Factory

    private static func make(id: Int, name: String, emoji: String, prepTime: Int = 0,
                              nightBefore: Bool = false,
                              ingredients: [String], steps: [String],
                              safeFor: [String]) -> Recipe {
        Recipe(
            id: UUID(uuidString: "00000000-0000-0000-0003-\(String(format: "%012d", id))")!,
            householdId: householdId,
            name: name,
            emoji: emoji,
            ingredients: ingredients,
            steps: steps.map { RecipeStep(text: $0, hoursBefore: 0) },
            safeForTags: safeFor,
            prepTimeMinutes: prepTime > 0 ? prepTime : nil,
            prepNightBefore: nightBefore,
            sourceUrl: nil,
            photoPath: nil,
            archived: false,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
