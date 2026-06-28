import Foundation
import CoreTransferable

// MARK: - Household

struct Household: Codable, Identifiable {
    let id: UUID
    var name: String
    var timezone: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, timezone
        case createdAt = "created_at"
    }
}

// MARK: - Member

struct Member: Codable, Identifiable, Equatable {
    let id: UUID
    let householdId: UUID
    let userId: UUID
    var displayName: String
    var dietaryRestrictions: [String]
    var apnsDeviceTokens: [String]
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId     = "household_id"
        case userId          = "user_id"
        case displayName     = "display_name"
        case dietaryRestrictions = "dietary_restrictions"
        case apnsDeviceTokens    = "apns_device_tokens"
        case joinedAt        = "joined_at"
    }
}

// MARK: - Recipe

struct Recipe: Codable, Identifiable, Transferable {
    let id: UUID
    let householdId: UUID
    var name: String
    var emoji: String
    var ingredients: [String]
    var steps: [RecipeStep]
    var safeForTags: [String]
    var prepTimeMinutes: Int?
    var prepNightBefore: Bool = false
    var sourceUrl: String?
    var photoPath: String?
    var archived: Bool
    let createdBy: UUID
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, emoji, ingredients, steps, name, archived
        case householdId     = "household_id"
        case safeForTags     = "safe_for_tags"
        case prepTimeMinutes = "prep_time_minutes"
        case prepNightBefore = "prep_night_before"
        case sourceUrl       = "source_url"
        case photoPath       = "photo_path"
        case createdBy       = "created_by"
        case createdAt       = "created_at"
        case updatedAt       = "updated_at"
    }

    // Custom decode so prepNightBefore defaults to false if the DB column isn't applied yet.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,       forKey: .id)
        householdId     = try c.decode(UUID.self,       forKey: .householdId)
        name            = try c.decode(String.self,     forKey: .name)
        emoji           = try c.decode(String.self,     forKey: .emoji)
        ingredients     = try c.decode([String].self,   forKey: .ingredients)
        steps           = try c.decode([RecipeStep].self, forKey: .steps)
        safeForTags     = try c.decode([String].self,   forKey: .safeForTags)
        prepTimeMinutes = try c.decodeIfPresent(Int.self,    forKey: .prepTimeMinutes)
        prepNightBefore = try c.decodeIfPresent(Bool.self,   forKey: .prepNightBefore) ?? false
        sourceUrl       = try c.decodeIfPresent(String.self, forKey: .sourceUrl)
        photoPath       = try c.decodeIfPresent(String.self, forKey: .photoPath)
        archived        = try c.decode(Bool.self,   forKey: .archived)
        createdBy       = try c.decode(UUID.self,   forKey: .createdBy)
        createdAt       = try c.decode(Date.self,   forKey: .createdAt)
        updatedAt       = try c.decode(Date.self,   forKey: .updatedAt)
    }

    init(id: UUID, householdId: UUID, name: String, emoji: String,
         ingredients: [String], steps: [RecipeStep], safeForTags: [String],
         prepTimeMinutes: Int? = nil, prepNightBefore: Bool = false,
         sourceUrl: String? = nil, photoPath: String? = nil,
         archived: Bool, createdBy: UUID, createdAt: Date, updatedAt: Date) {
        self.id              = id
        self.householdId     = householdId
        self.name            = name
        self.emoji           = emoji
        self.ingredients     = ingredients
        self.steps           = steps
        self.safeForTags     = safeForTags
        self.prepTimeMinutes = prepTimeMinutes
        self.prepNightBefore = prepNightBefore
        self.sourceUrl       = sourceUrl
        self.photoPath       = photoPath
        self.archived        = archived
        self.createdBy       = createdBy
        self.createdAt       = createdAt
        self.updatedAt       = updatedAt
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .recipe)
    }
}

struct RecipeStep: Codable {
    var text: String
    var hoursBefore: Int

    enum CodingKeys: String, CodingKey {
        case text
        case hoursBefore = "hours_before"
    }
}

// MARK: - Meal Slot

enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, dinner

    var label: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        }
    }

    var shortLabel: String {
        switch self {
        case .breakfast: return "B"
        case .lunch:     return "L"
        case .dinner:    return "D"
        }
    }
}

struct MealSlot: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var slotDate: Date
    var mealType: MealType
    var recipeId: UUID?
    var updatedBy: UUID?
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, mealType = "meal_type"
        case householdId  = "household_id"
        case slotDate     = "slot_date"
        case recipeId     = "recipe_id"
        case updatedBy    = "updated_by"
        case updatedAt    = "updated_at"
    }
}

// MARK: - Invite Token

struct InviteToken: Codable {
    let id: UUID
    let householdId: UUID
    let token: String
    let createdBy: UUID
    let expiresAt: Date
    var usedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, token
        case householdId = "household_id"
        case createdBy   = "created_by"
        case expiresAt   = "expires_at"
        case usedAt      = "used_at"
    }
}

// MARK: - UTType extension for drag-and-drop

import UniformTypeIdentifiers

extension UTType {
    static let recipe = UTType(exportedAs: "com.mealomemory.recipe")
}
