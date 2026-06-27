import Foundation
import PhotosUI
import SwiftUI
import Vision

@MainActor
final class AddRecipeViewModel: ObservableObject {
    enum EntryMethod: CaseIterable {
        case camera, url, manual

        var icon: String {
            switch self { case .camera: "📷"; case .url: "🔗"; case .manual: "✏️" }
        }
        var label: String {
            switch self { case .camera: "Camera"; case .url: "URL"; case .manual: "Manual" }
        }
    }

    @Published var entryMethod: EntryMethod? = nil
    @Published var name = ""
    @Published var emoji = ""
    @Published var ingredients: [String] = [""]
    @Published var steps: [RecipeStep] = [RecipeStep(text: "", hoursBefore: 0)]
    @Published var safeForTags: [String] = []
    @Published var prepTimeMinutes: Int = 0
    @Published var dishPhoto: UIImage?
    @Published var isOCRProcessing = false
    @Published var isImporting = false
    @Published var isSaving = false
    @Published var importError: String?
    @Published var saveError: String?

    private(set) var editingRecipe: Recipe?
    var isEditing: Bool { editingRecipe != nil }

    // Pre-generated for new recipes so photo can be uploaded before the INSERT.
    private let pendingId = UUID()

    private let recipeService = RecipeService()

    init(editing recipe: Recipe? = nil) {
        if let recipe {
            editingRecipe = recipe
            name = recipe.name
            emoji = recipe.emoji
            ingredients = recipe.ingredients.isEmpty ? [""] : recipe.ingredients
            steps = recipe.steps.isEmpty ? [RecipeStep(text: "", hoursBefore: 0)] : recipe.steps
            safeForTags = recipe.safeForTags
            prepTimeMinutes = recipe.prepTimeMinutes ?? 0
            entryMethod = .manual
            // dishPhoto stays nil — the existing photo is shown via signed URL in RecipeDetailView.
            // A new pick in the edit sheet replaces it.
        }
    }

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: - OCR

    func processPhotoItem(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        isOCRProcessing = true
        defer { isOCRProcessing = false }

        guard let cgImage = uiImage.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try? handler.perform([request])

        let lines = request.results?
            .compactMap { $0.topCandidates(1).first?.string } ?? []

        parseOCRLines(lines)
    }

    private func parseOCRLines(_ lines: [String]) {
        // Heuristic: lines matching a quantity pattern → ingredients; rest → steps
        let quantityPattern = #"^\d[\d\/\s]*(cup|tbsp|tsp|kg|g|ml|l|pinch|handful|clove|piece)?\s+.+"#
        let regex = try? NSRegularExpression(pattern: quantityPattern, options: .caseInsensitive)

        var detectedIngredients: [String] = []
        var detectedSteps: [RecipeStep] = []

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if regex?.firstMatch(in: line, range: range) != nil {
                detectedIngredients.append(line)
            } else if line.count > 10 {
                detectedSteps.append(RecipeStep(text: line, hoursBefore: 0))
            } else if name.isEmpty {
                name = line
            }
        }

        if !detectedIngredients.isEmpty { ingredients = detectedIngredients }
        if !detectedSteps.isEmpty { steps = detectedSteps }
    }

    // MARK: - URL Import

    func importURL(_ urlString: String) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) else {
            importError = "That doesn't look like a valid URL."
            return
        }
        isImporting = true
        importError = nil
        defer { isImporting = false }

        do {
            let result = try await RecipeImportService.shared.importRecipe(from: url)
            name        = result.name
            emoji       = result.emoji ?? "🍽"
            ingredients = result.ingredients.isEmpty ? [""] : result.ingredients
            steps       = result.steps.isEmpty
                ? [RecipeStep(text: "", hoursBefore: 0)]
                : result.steps.map { RecipeStep(text: $0, hoursBefore: 0) }
        } catch {
            importError = "Couldn't fetch that recipe. Try copying the text manually."
        }
    }

    // MARK: - Save

    func save(householdId: UUID) async -> Recipe? {
        isSaving = true
        defer { isSaving = false }
        do {
            if var existing = editingRecipe {
                existing.name = name.trimmingCharacters(in: .whitespaces)
                existing.emoji = emoji.isEmpty ? "🍽" : emoji
                existing.ingredients = ingredients.filter { !$0.isEmpty }
                existing.steps = steps.filter { !$0.text.isEmpty }
                existing.safeForTags = safeForTags
                existing.prepTimeMinutes = prepTimeMinutes > 0 ? prepTimeMinutes : nil
                if let photo = dishPhoto,
                   let path = try? await recipeService.uploadPhoto(photo, householdId: householdId, recipeId: existing.id) {
                    existing.photoPath = path
                }
                return try await recipeService.updateRecipe(existing)
            } else {
                // Upload photo first using pre-generated ID so path is included in the INSERT.
                var photoPath: String?
                if let photo = dishPhoto {
                    photoPath = try? await recipeService.uploadPhoto(photo, householdId: householdId, recipeId: pendingId)
                }
                return try await recipeService.createRecipe(
                    householdId: householdId,
                    id: pendingId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    emoji: emoji.isEmpty ? "🍽" : emoji,
                    ingredients: ingredients.filter { !$0.isEmpty },
                    steps: steps.filter { !$0.text.isEmpty },
                    safeForTags: safeForTags,
                    prepTimeMinutes: prepTimeMinutes > 0 ? prepTimeMinutes : nil,
                    photoPath: photoPath
                )
            }
        } catch {
            saveError = error.localizedDescription
            return nil
        }
    }
}
