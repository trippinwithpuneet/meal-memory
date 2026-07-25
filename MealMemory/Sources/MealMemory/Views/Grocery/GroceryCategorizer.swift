import Foundation

// Shopping-aisle buckets for the weekly grocery list (TRI-11).
// Order here is the display order (roughly a sensible store walk).
enum GroceryAisle: Int, CaseIterable, Identifiable {
    case fruitVeg
    case dryPantry
    case dairyBreadEggs
    case meatFish
    case other

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fruitVeg:       return "Fruit & Vegetables"
        case .dryPantry:      return "Dry Pantry"
        case .dairyBreadEggs: return "Dairy / Bread & Eggs"
        case .meatFish:       return "Meat & Fish"
        case .other:          return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .fruitVeg:       return "🥬"
        case .dryPantry:      return "🌾"
        case .dairyBreadEggs: return "🥚"
        case .meatFish:       return "🍗"
        case .other:          return "🧂"
        }
    }
}

// Static, offline keyword → aisle mapping. Deliberately simple and deterministic
// (an LLM fallback for unmatched items is a future follow-up — see TRI-11 notes).
enum GroceryCategorizer {

    // Checked in priority order so collisions resolve predictably
    // (e.g. "bell pepper" → produce, while "salt and pepper" → pantry via "salt").
    private static let keywordsByAisle: [(GroceryAisle, [String])] = [
        (.meatFish, [
            "chicken", "beef", "pork", "bacon", "sausage", "turkey", "lamb", "ham",
            "mince", "ground ", "steak", "thigh", "breast", "tuna", "salmon",
            "shrimp", "prawn", "cod", "fish", "tofu"
        ]),
        (.dairyBreadEggs, [
            "egg", "milk", "butter", "cheese", "paneer", "yogurt", "yoghurt",
            "cream", "bread", "sourdough", "bun", "tortilla", "naan", "pita",
            "mozzarella", "parmesan", "feta", "bagel"
        ]),
        // Pantry is checked BEFORE produce so canned legumes (chickpeas, beans,
        // lentils) don't get caught by the produce "pea"/"bean" substrings.
        (.dryPantry, [
            "rice", "pasta", "spaghetti", "noodle", "flour", "sugar", "oil", "salt",
            "black pepper", "peppercorn", "bean", "chickpea", "lentil", "dal",
            "quinoa", "oat", "granola", "cereal", "tahini", "soy sauce", "tamari",
            "vinegar", "stock", "broth", "cumin", "paprika", "turmeric", "cinnamon",
            "baking powder", "honey", "syrup", "chia", "seed", "almond", "nut",
            "canned", "can ", "tomato paste", "coconut", "sauce", "mustard", "mayo",
            "ketchup", "sesame", "spice", "stock cube", "couscous", "tinned"
        ]),
        (.fruitVeg, [
            "tomato", "avocado", "onion", "shallot", "scallion", "garlic", "ginger",
            "bell pepper", "red pepper", "green pepper", "peppers", "chilli", "chili",
            "broccoli", "spinach", "lettuce", "cucumber", "lime", "lemon", "orange",
            "mandarin", "apple", "banana", "berry", "berries", "carrot", "celery",
            "potato", "beet", "mushroom", "zucchini", "courgette", "corn", "pea",
            "cilantro", "coriander", "parsley", "basil", "herb", "kale", "cabbage",
            "greens", "salad", "lime", "cauliflower", "asparagus", "leek"
        ])
    ]

    static func aisle(for ingredient: String) -> GroceryAisle {
        let s = ingredient.lowercased()
        for (aisle, keywords) in keywordsByAisle {
            if keywords.contains(where: { s.contains($0) }) { return aisle }
        }
        return .other
    }
}
