import XCTest
@testable import MealMemory

/// Evals for the Recipe decoder.
///
/// This matters more than usual here: two migrations (`prep_time_minutes`,
/// `prep_night_before`) are still unapplied on the live database, so the app
/// must decode rows that lack those columns without failing the whole fetch.
/// A regression would empty the recipe bank for every user on the old schema.
final class RecipeCodableTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private let fullRow = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "household_id": "22222222-2222-2222-2222-222222222222",
      "name": "Burrito Bowl",
      "emoji": "🌯",
      "ingredients": ["rice", "black beans", "avocado"],
      "steps": [{"text": "Warm the rice", "hours_before": 0}],
      "safe_for_tags": ["Gluten-free"],
      "prep_time_minutes": 25,
      "prep_night_before": true,
      "source_url": "https://example.com/burrito-bowl",
      "photo_path": "household/recipe/photo.jpg",
      "archived": false,
      "created_by": "33333333-3333-3333-3333-333333333333",
      "created_at": "2026-07-01T10:00:00Z",
      "updated_at": "2026-07-02T10:00:00Z"
    }
    """

    /// What the live database actually returns today: no prep columns, no source.
    private let legacyRow = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "household_id": "22222222-2222-2222-2222-222222222222",
      "name": "Egg Sandwich",
      "emoji": "🥪",
      "ingredients": ["bread", "eggs"],
      "steps": [],
      "safe_for_tags": [],
      "archived": false,
      "created_by": "33333333-3333-3333-3333-333333333333",
      "created_at": "2026-07-01T10:00:00Z",
      "updated_at": "2026-07-02T10:00:00Z"
    }
    """

    func testDecodesAFullRowIncludingSnakeCaseKeys() throws {
        let r = try decoder().decode(Recipe.self, from: Data(fullRow.utf8))
        XCTAssertEqual(r.name, "Burrito Bowl")
        XCTAssertEqual(r.emoji, "🌯")
        XCTAssertEqual(r.ingredients, ["rice", "black beans", "avocado"])
        XCTAssertEqual(r.safeForTags, ["Gluten-free"])
        XCTAssertEqual(r.prepTimeMinutes, 25)
        XCTAssertTrue(r.prepNightBefore)
        XCTAssertEqual(r.sourceUrl, "https://example.com/burrito-bowl")
        XCTAssertEqual(r.photoPath, "household/recipe/photo.jpg")
        XCTAssertFalse(r.archived)
        XCTAssertEqual(r.steps.first?.text, "Warm the rice")
        XCTAssertEqual(r.steps.first?.hoursBefore, 0)
    }

    func testDecodesALegacyRowWhoseMigrationsHaveNotBeenApplied() throws {
        // The whole point of the custom init(from:) — this must not throw.
        let r = try decoder().decode(Recipe.self, from: Data(legacyRow.utf8))
        XCTAssertEqual(r.name, "Egg Sandwich")
        XCTAssertNil(r.prepTimeMinutes)
        XCTAssertFalse(r.prepNightBefore, "must default to false, not fail the decode")
        XCTAssertNil(r.sourceUrl)
        XCTAssertNil(r.photoPath)
    }

    func testExplicitNullsDecodeAsNil() throws {
        let json = legacyRow.replacingOccurrences(
            of: "\"archived\": false",
            with: "\"archived\": false, \"prep_time_minutes\": null, \"source_url\": null"
        )
        let r = try decoder().decode(Recipe.self, from: Data(json.utf8))
        XCTAssertNil(r.prepTimeMinutes)
        XCTAssertNil(r.sourceUrl)
    }

    func testMissingRequiredFieldFailsLoudlyRatherThanSilently() {
        // `name` is not optional — a row without it is corrupt and should throw
        // so the failure surfaces, instead of rendering a nameless card.
        let broken = legacyRow.replacingOccurrences(of: "\"name\": \"Egg Sandwich\",", with: "")
        XCTAssertThrowsError(try decoder().decode(Recipe.self, from: Data(broken.utf8)))
    }

    func testRoundTripsThroughEncodeAndDecode() throws {
        let original = try decoder().decode(Recipe.self, from: Data(fullRow.utf8))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reDecoded = try decoder().decode(Recipe.self, from: try encoder.encode(original))

        XCTAssertEqual(reDecoded.id, original.id)
        XCTAssertEqual(reDecoded.name, original.name)
        XCTAssertEqual(reDecoded.ingredients, original.ingredients)
        XCTAssertEqual(reDecoded.prepNightBefore, original.prepNightBefore)
        XCTAssertEqual(reDecoded.sourceUrl, original.sourceUrl)
    }

    func testDecodesAnArrayOfRowsWithMixedSchemas() throws {
        // Realistic mid-migration state: some rows have the new columns, some don't.
        let json = "[\(fullRow),\(legacyRow)]"
        let recipes = try decoder().decode([Recipe].self, from: Data(json.utf8))
        XCTAssertEqual(recipes.count, 2)
    }

    // MARK: - MealSlot

    func testMealSlotDecodesWithANullRecipe() throws {
        let json = """
        {
          "id": "44444444-4444-4444-4444-444444444444",
          "household_id": "22222222-2222-2222-2222-222222222222",
          "slot_date": "2026-08-10T00:00:00Z",
          "meal_type": "dinner",
          "recipe_id": null,
          "updated_by": null,
          "updated_at": "2026-08-10T10:00:00Z"
        }
        """
        let slot = try decoder().decode(MealSlot.self, from: Data(json.utf8))
        XCTAssertNil(slot.recipeId, "a cleared slot is a normal state, not an error")
        XCTAssertEqual(slot.mealType, .dinner)
    }

    func testMealTypeRoundTripsThroughItsRawValue() {
        for type in MealType.allCases {
            XCTAssertEqual(MealType(rawValue: type.rawValue), type)
            XCTAssertFalse(type.label.isEmpty)
        }
    }

    // The grid label and the text label are deliberately different things.
    // Dessert (added 2026-08-30) uses 🍰 in the grid because "D" is taken by
    // dinner and the column is 20pt — but a glyph in the SHARE TEXT would render
    // as "🍪 🍰: Tahini Cookies", two emoji and no word. These two assertions
    // pin each label to its own job.
    func testGridLabelIsASingleCharacterThatFitsTheColumn() {
        for type in MealType.allCases {
            XCTAssertEqual(type.gridLabel.count, 1,
                           "\(type.rawValue): the grid column is 20pt — one character only")
        }
    }

    func testShortLabelStaysPlainTextForSharedPlans() {
        for type in MealType.allCases {
            XCTAssertFalse(type.shortLabel.isEmpty)
            XCTAssertTrue(type.shortLabel.canBeConverted(to: .ascii),
                          "\(type.rawValue): shortLabel goes into the shared plan text — "
                          + "an emoji here collides with the recipe's own emoji")
        }
    }
}
