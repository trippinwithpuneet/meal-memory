import Foundation

// Toggle this to true to run the app with pre-loaded fake data on the simulator.
// No network calls are made in demo mode — safe to use on iOS 26.5 simulator.
enum DemoData {
    static let isDemoMode = true

    static let householdId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let userId      = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    // MARK: - Members

    static let members: [Member] = [
        Member(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
            householdId: householdId,
            userId: userId,
            displayName: "Puneet",
            dietaryRestrictions: ["Gluten-free", "No milk"],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
        Member(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            householdId: householdId,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            displayName: "Rachel",
            dietaryRestrictions: [],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
    ]

    // MARK: - Recipes
    //
    // Recipe index reference (used in slot assignments below):
    //   0  Burrito Bowl          — both safe ✅
    //   1  Chana Salad           — both safe ✅
    //   2  Quinoa Beetroot Bowl  — both safe ✅
    //   3  Spaghetti Aglio e Olio — Puneet conflict (gluten) ❌
    //   4  Egg Sandwich          — Puneet conflict (gluten) ❌
    //   5  Moong Dal Chilla      — both safe ✅
    //   6  Paneer Bhurji         — Puneet conflict (milk) ❌
    //   7  Pancakes              — Puneet conflict (gluten + milk) ❌
    //   8  Tofu Stir Fry         — both safe ✅
    //   9  Tuna & Egg Salad      — both safe ✅

    static let recipes: [Recipe] = [

        // ── Both safe ──────────────────────────────────────────────────────────

        make(id: 1, name: "Burrito Bowl", emoji: "🌯", prepTime: 30,
             ingredients: ["1 cup basmati rice",
                           "1 can black beans, drained",
                           "1 cup frozen corn",
                           "1 ripe avocado",
                           "1 cup cherry tomatoes",
                           "2 limes",
                           "small bunch coriander",
                           "1 tsp cumin, salt, olive oil"],
             steps: ["Cook rice with cumin and salt until fluffy",
                     "Warm black beans and corn in a pan for 3 min",
                     "Halve tomatoes, dice avocado, roughly chop coriander",
                     "Assemble bowls: rice base, then beans, corn",
                     "Top with avocado, tomatoes, coriander and a good squeeze of lime"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        make(id: 2, name: "Chana Salad", emoji: "🥗", prepTime: 15,
             ingredients: ["1 can chickpeas, drained",
                           "2 mandarin oranges, segmented",
                           "1 cucumber, diced",
                           "½ red onion, finely diced",
                           "3 tbsp mayo",
                           "1 lemon, juiced",
                           "small bunch coriander, chilli flakes"],
             steps: ["Drain and rinse chickpeas; dice cucumber; segment mandarins",
                     "Whisk mayo with lemon juice, salt and pepper",
                     "Toss chickpeas, cucumber and onion with dressing",
                     "Top with mandarin segments, coriander and a pinch of chilli flakes"],
             safeFor: ["Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        make(id: 3, name: "Quinoa Beetroot Bowl", emoji: "🥣", prepTime: 35,
             ingredients: ["1 cup quinoa",
                           "250g pre-cooked beetroot",
                           "2 handfuls baby spinach",
                           "3 tbsp tahini",
                           "1 lemon, juiced",
                           "1 garlic clove, minced",
                           "2 tbsp pumpkin seeds, toasted"],
             steps: ["Rinse quinoa; cook in 2 cups water for 15 min until fluffy, then rest 5 min",
                     "Slice beetroot into wedges",
                     "Whisk tahini with lemon, garlic and 2 tbsp water until smooth",
                     "Assemble: quinoa, spinach, beetroot; drizzle dressing, scatter seeds"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        // ── Puneet conflict: gluten ────────────────────────────────────────────

        make(id: 4, name: "Spaghetti Aglio e Olio", emoji: "🍝", prepTime: 25,
             ingredients: ["300g spaghetti",
                           "6 garlic cloves, thinly sliced",
                           "4 tbsp olive oil",
                           "1 tsp red chilli flakes",
                           "small bunch parsley, chopped",
                           "salt",
                           "reserved pasta water"],
             steps: ["Boil spaghetti in well-salted water until al dente; reserve 1 cup pasta water",
                     "Gently sauté garlic in olive oil over low heat until golden — don't let it burn",
                     "Add chilli flakes, then drained pasta and a splash of pasta water",
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

        // ── Both safe: Rachel's Indian proteins ───────────────────────────────

        make(id: 6, name: "Moong Dal Chilla", emoji: "🫓", prepTime: 25,
             ingredients: ["1 cup split green moong dal",
                           "1 tsp grated ginger",
                           "1 green chilli, finely chopped",
                           "½ onion, finely diced",
                           "small bunch coriander, chopped",
                           "½ tsp cumin",
                           "salt and oil for cooking"],
             steps: ["Soak dal overnight (or at least 4 hours); drain well",
                     "Blend soaked dal with ginger, cumin, salt and just enough water for a pourable batter",
                     "Stir in diced onion, green chilli and coriander",
                     "Ladle onto a hot oiled pan; spread thin like a crepe; cook 2 min per side until golden"],
             safeFor: ["Vegan", "Vegetarian", "Gluten-free", "No milk", "Dairy-free"]),

        // ── Puneet conflict: milk ──────────────────────────────────────────────

        make(id: 7, name: "Paneer Bhurji", emoji: "🧀", prepTime: 25,
             ingredients: ["250g paneer, crumbled",
                           "1 onion, finely diced",
                           "2 tomatoes, chopped",
                           "2 garlic cloves, minced",
                           "1 tsp grated ginger",
                           "1 green chilli, chopped",
                           "½ tsp turmeric",
                           "1 tsp cumin seeds",
                           "1 tsp garam masala",
                           "coriander and oil to finish"],
             steps: ["Sauté cumin seeds in oil; add onion and cook until golden",
                     "Add garlic, ginger, chilli and cook 2 min; add tomatoes and cook until oil separates",
                     "Add turmeric and garam masala; stir well",
                     "Add crumbled paneer, fold gently and cook 3 min; finish with coriander"],
             safeFor: ["Vegetarian", "Gluten-free"]),

        // ── Puneet conflict: gluten + milk ─────────────────────────────────────

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
            (0, .breakfast, 5),   // Mon breakfast: Moong Dal Chilla ✅ both
            (0, .lunch,     1),   // Mon lunch:     Chana Salad ✅ both
            (0, .dinner,    6),   // Mon dinner:    Paneer Bhurji ❌ Puneet (milk)
            (1, .breakfast, 7),   // Tue breakfast: Pancakes ❌ Puneet (gluten + milk)
            (1, .lunch,     2),   // Tue lunch:     Quinoa Beetroot Bowl ✅ both
            (1, .dinner,    3),   // Tue dinner:    Spaghetti Aglio e Olio ❌ Puneet (gluten)
            (2, .lunch,     0),   // Wed lunch:     Burrito Bowl ✅ both
            (2, .dinner,    8),   // Wed dinner:    Tofu Stir Fry ✅ both
            (3, .lunch,     9),   // Thu lunch:     Tuna & Egg Salad ✅ both
            (3, .dinner,    5),   // Thu dinner:    Moong Dal Chilla ✅ both
            (4, .breakfast, 4),   // Fri breakfast: Egg Sandwich ❌ Puneet (gluten)
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
            sourceUrl: nil,
            photoPath: nil,
            archived: false,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
