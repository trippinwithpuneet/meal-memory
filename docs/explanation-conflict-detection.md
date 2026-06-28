# Dietary Conflict Detection and the Night-Before Prep Indicator

## Current design: 🌙 night-before prep indicator

The week plan grid currently shows one indicator on slot cells: a **🌙 moon** (top-right corner) when the planned recipe needs overnight preparation — soaking beans, marinating, defrosting, etc.

This is stored as `prep_night_before: Bool` on the `Recipe` model and set when creating or editing a recipe. The indicator is purely data-driven: if the flag is true and the recipe is placed in a slot, the 🌙 appears.

Long-pressing a 🌙 slot surfaces a context menu: "Prep needed the night before."

## Why the conflict red dot was removed

Earlier versions showed a red dot and red border on slots where the planned recipe didn't satisfy all household members' dietary restrictions. This was removed for a product reason: in a household that plans meals together, members already know each other's restrictions at plan time. A couple where one person is gluten-free doesn't plan spaghetti for dinner and then discover a conflict — they know. The red dot created visual noise without adding decision-relevant information.

The **conflict detection function** (`MealPlanViewModel.dietaryConflicts(for:using:)`) is preserved in the codebase for future use:

```swift
func dietaryConflicts(for recipe: Recipe, using members: [Member]) -> [String] {
    let allRestrictions = Set(members.flatMap { $0.dietaryRestrictions })
    return allRestrictions.filter { !recipe.safeForTags.contains($0) }.sorted()
}
```

It unions all members' restrictions and returns any not covered by `safe_for_tags`. If a future feature (e.g. a recipe suggestion engine, or a household with more members) needs conflict data, the computation is ready.

## How member restriction data flows

`WeekGridView` reads `appState.members` (not `viewModel.members`). `AppState` is updated synchronously when a member saves restriction edits in `HouseholdView`, so any future conflict-aware UI would have real-time data without a DB round-trip.

`AppState.applyLocalRestrictions()` overlays UserDefaults-cached member data on top of freshly fetched DB rows — meaning restriction edits made on this device are reflected immediately, even before the Supabase write completes.

## Night-before prep: data path

1. When creating/editing a recipe, toggle **"Needs night-before prep"** in the form.
2. `AddRecipeViewModel.prepNightBefore: Bool` is saved to the `prep_night_before` column.
3. When `MealPlanViewModel.load()` or `reloadSlots()` runs, recipes with `prepNightBefore = true` are included in `self.recipes`.
4. `WeekGridView.mealRow()` reads `recipe?.prepNightBefore == true` and passes `needsNightBefore` to `SlotCell`.
5. `SlotCell` renders the 🌙 emoji in the top-right corner.

In demo mode the flag is set on Burrito Bowl and Moong Dal Chilla (both require overnight soaking).

## Related

- [Dietary Tags Reference](reference-dietary-tags.md)
- [How to Set Dietary Restrictions](howto-dietary-restrictions.md)
- [Data Model Reference](reference-data-model.md) — `prep_night_before` column
- [Architecture Overview](explanation-architecture.md) — why AppState.members instead of viewModel.members
