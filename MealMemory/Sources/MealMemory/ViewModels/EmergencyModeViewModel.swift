import Foundation
import Combine

struct EmergencyResult: Identifiable {
    let id: UUID
    let recipe: Recipe
    let matchCount: Int
    let missingIngredients: [String]
    let matchingIngredients: [String]

    var matchScore: Double {
        guard !recipe.ingredients.isEmpty else { return 0 }
        return Double(matchCount) / Double(recipe.ingredients.count)
    }

    var matchPercent: Int { Int(matchScore * 100) }
}

@MainActor
final class EmergencyModeViewModel: ObservableObject {
    @Published var ingredientInput = ""
    @Published var typedIngredients: [String] = []
    @Published var results: [EmergencyResult] = []
    @Published var selectedResult: EmergencyResult?

    // All household recipes — injected from parent so no extra fetch needed
    var allRecipes: [Recipe] = []

    // MARK: - Ingredient management

    func addIngredient(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !typedIngredients.contains(where: {
            $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) else { return }
        typedIngredients.append(trimmed)
        ingredientInput = ""
        search()
    }

    func removeIngredient(_ ingredient: String) {
        typedIngredients.removeAll { $0 == ingredient }
        search()
    }

    // MARK: - Search

    func search() {
        guard !typedIngredients.isEmpty else {
            results = []
            return
        }

        let normalised = typedIngredients.map { $0.lowercased() }

        results = allRecipes.compactMap { recipe -> EmergencyResult? in
            let recipeIngredients = recipe.ingredients.map { $0.lowercased() }

            let matching = recipeIngredients.filter { recipeIng in
                normalised.contains { typed in recipeIng.contains(typed) || typed.contains(recipeIng) }
            }
            let missing = recipe.ingredients.filter { recipeIng in
                !normalised.contains { typed in
                    recipeIng.lowercased().contains(typed) || typed.contains(recipeIng.lowercased())
                }
            }

            // Only show recipes where at least 1 ingredient matches
            guard !matching.isEmpty else { return nil }

            return EmergencyResult(
                id: recipe.id,
                recipe: recipe,
                matchCount: matching.count,
                missingIngredients: missing,
                matchingIngredients: matching
            )
        }
        .sorted { $0.matchScore > $1.matchScore }
    }
}
