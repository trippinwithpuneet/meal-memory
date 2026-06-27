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
            dietaryRestrictions: ["Vegetarian"],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
        Member(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            householdId: householdId,
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            displayName: "Priya",
            dietaryRestrictions: ["No onion-garlic"],
            apnsDeviceTokens: [],
            joinedAt: Date()
        ),
    ]

    // MARK: - Recipes

    static let recipes: [Recipe] = [
        make(id: 1, name: "Dal Makhani",          emoji: "🫕",
             ingredients: ["1 cup black lentils", "1/2 cup kidney beans", "2 tbsp butter",
                           "1 onion", "2 garlic cloves", "1 tsp cumin", "200ml cream",
                           "1 tsp garam masala", "salt to taste"],
             steps: ["Soak lentils overnight", "Pressure cook for 20 min",
                     "Sauté onion and garlic in butter", "Add spices and cook 5 min",
                     "Add lentils and simmer 30 min", "Finish with cream"],
             safeFor: ["Vegetarian", "Gluten-free"]),   // has onion-garlic → conflict with Priya

        make(id: 2, name: "Jeera Rice",            emoji: "🍚",
             ingredients: ["2 cups basmati rice", "1 tsp cumin seeds", "1 tbsp ghee",
                           "4 cups water", "salt to taste"],
             steps: ["Wash and soak rice 20 min", "Heat ghee and splutter cumin",
                     "Add rice and water", "Cook until tender"],
             safeFor: ["Vegetarian", "Vegan", "No onion-garlic", "Gluten-free", "Dairy-free"]),

        make(id: 3, name: "Paneer Butter Masala", emoji: "🧀",
             ingredients: ["300g paneer", "2 onions", "3 tomatoes", "2 tbsp butter",
                           "4 garlic cloves", "1 tsp ginger", "1/2 cup cream",
                           "1 tsp kashmiri chilli", "1 tsp garam masala"],
             steps: ["Fry paneer cubes until golden", "Make onion-tomato-garlic paste",
                     "Cook paste in butter 10 min", "Add spices and cream",
                     "Add paneer and simmer 10 min"],
             safeFor: ["Vegetarian"]),                  // has onion-garlic → conflict with Priya

        make(id: 4, name: "Aloo Paratha",          emoji: "🫓",
             ingredients: ["2 cups wheat flour", "3 potatoes boiled", "1 tsp cumin powder",
                           "1/2 tsp amchur", "2 tbsp coriander", "salt", "ghee for cooking"],
             steps: ["Knead soft dough", "Mash potatoes with spices",
                     "Stuff dough with potato mix", "Roll and cook on tawa with ghee"],
             safeFor: ["Vegetarian", "No onion-garlic"]),

        make(id: 5, name: "Chana Masala",          emoji: "🍛",
             ingredients: ["2 cups chickpeas", "2 tomatoes", "1 tsp cumin", "1 tsp coriander powder",
                           "1/2 tsp turmeric", "1 tsp amchur", "1 tsp chilli powder",
                           "1 tbsp oil", "salt"],
             steps: ["Soak and boil chickpeas", "Make tomato base",
                     "Add spices and chickpeas", "Simmer 15 min"],
             safeFor: ["Vegetarian", "Vegan", "No onion-garlic", "Gluten-free", "Dairy-free"]),

        make(id: 6, name: "Mango Lassi",           emoji: "🥭",
             ingredients: ["1 cup yogurt", "1 ripe mango", "2 tbsp sugar", "1/2 cup milk",
                           "pinch of cardamom"],
             steps: ["Blend all ingredients until smooth", "Chill and serve"],
             safeFor: ["Vegetarian", "Gluten-free", "No onion-garlic"]),
    ]

    // MARK: - Slots (populated relative to current week start)

    static func slots(for weekStart: Date) -> [String: MealSlot] {
        let cal = Calendar(identifier: .gregorian)
        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: weekStart)!
        }

        let r = recipes
        let assignments: [(offset: Int, meal: MealType, recipeIndex: Int)] = [
            (0, .lunch,     0),   // Mon lunch:   Dal Makhani     (red dot — Priya)
            (0, .dinner,    1),   // Mon dinner:  Jeera Rice
            (1, .breakfast, 5),   // Tue breakfast: Mango Lassi
            (1, .lunch,     4),   // Tue lunch:   Chana Masala
            (1, .dinner,    2),   // Tue dinner:  Paneer Butter Masala (red dot)
            (2, .lunch,     3),   // Wed lunch:   Aloo Paratha
            (2, .dinner,    0),   // Wed dinner:  Dal Makhani     (red dot)
            (3, .lunch,     4),   // Thu lunch:   Chana Masala
            (3, .dinner,    1),   // Thu dinner:  Jeera Rice
            (4, .breakfast, 5),   // Fri breakfast: Mango Lassi
            (4, .dinner,    2),   // Fri dinner:  Paneer Butter Masala (red dot)
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

    private static func make(id: Int, name: String, emoji: String,
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
            sourceUrl: nil,
            photoPath: nil,
            archived: false,
            createdBy: userId,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
