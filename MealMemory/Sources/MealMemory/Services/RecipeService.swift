import Foundation
import Supabase
import UIKit

@MainActor
final class RecipeService: ObservableObject {
    private let client = AppSupabase.client

    func fetchRecipes(householdId: UUID) async throws -> [Recipe] {
        try await client
            .from("recipes")
            .select()
            .eq("household_id", value: householdId)
            .eq("archived", value: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createRecipe(
        householdId: UUID,
        id: UUID = UUID(),
        name: String,
        emoji: String,
        ingredients: [String],
        steps: [RecipeStep],
        safeForTags: [String],
        sourceUrl: String? = nil,
        photoPath: String? = nil
    ) async throws -> Recipe {
        guard let userId = AuthService.shared.userId else { throw AppError.notAuthenticated }

        let now = Date()
        var payload: [String: AnyJSON] = [
            "id":            .string(id.uuidString),
            "household_id":  .string(householdId.uuidString),
            "name":          .string(name),
            "emoji":         .string(emoji),
            "ingredients":   .array(ingredients.map { .string($0) }),
            "steps":         .array(steps.map { stepsToAnyJSON($0) }),
            "safe_for_tags": .array(safeForTags.map { .string($0) }),
            "source_url":    sourceUrl.map { .string($0) } ?? .null,
            "created_by":    .string(userId.uuidString)
        ]
        if let photoPath { payload["photo_path"] = .string(photoPath) }

        let c = client
        Task.detached { try? await c.from("recipes").insert(payload).execute() }

        return Recipe(
            id: id,
            householdId: householdId,
            name: name,
            emoji: emoji,
            ingredients: ingredients,
            steps: steps,
            safeForTags: safeForTags,
            sourceUrl: sourceUrl,
            photoPath: photoPath,
            archived: false,
            createdBy: userId,
            createdAt: now,
            updatedAt: now
        )
    }

    func setArchived(_ archived: Bool, recipeId: UUID) async throws {
        let c = client
        Task.detached { try? await c.from("recipes").update(["archived": AnyJSON.bool(archived)]).eq("id", value: recipeId).execute() }
    }

    func updateRecipe(_ recipe: Recipe) async throws -> Recipe {
        var payload: [String: AnyJSON] = [
            "name":          .string(recipe.name),
            "emoji":         .string(recipe.emoji),
            "ingredients":   .array(recipe.ingredients.map { .string($0) }),
            "steps":         .array(recipe.steps.map { stepsToAnyJSON($0) }),
            "safe_for_tags": .array(recipe.safeForTags.map { .string($0) })
        ]
        if let photoPath = recipe.photoPath { payload["photo_path"] = .string(photoPath) }

        let c = client
        let recipeId = recipe.id
        Task.detached { try? await c.from("recipes").update(payload).eq("id", value: recipeId).execute() }
        return recipe
    }

    func deleteRecipe(id: UUID) async throws {
        try await client
            .from("recipes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Helpers

    private func stepsToAnyJSON(_ step: RecipeStep) -> AnyJSON {
        .object([
            "text":         .string(step.text),
            "hours_before": .integer(step.hoursBefore)
        ])
    }

    // MARK: - Photo upload (returns storage path)

    func uploadPhoto(_ image: UIImage, householdId: UUID, recipeId: UUID) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.unknown("Could not compress image.")
        }
        let path = "\(householdId.uuidString)/\(recipeId.uuidString)/photo.jpg"
        try await client.storage
            .from("recipe-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return path
    }

    // Returns a short-lived signed URL (1 hour) — never a public URL (bucket is private)
    func signedPhotoURL(path: String) async throws -> URL {
        let response = try await client.storage
            .from("recipe-photos")
            .createSignedURL(path: path, expiresIn: 3600)
        return response
    }
}
