# Dietary Conflict Detection

Conflict detection answers: "Is this recipe safe for everyone in the household to eat?"

## End-to-end flow

```
Member dietary_restrictions (DB / UserDefaults)
           │
           ▼
  HouseholdView → appState.members (EnvironmentObject)
           │
           ▼
  WeekGridView reads appState.members at render time
           │
           ▼
  MealPlanViewModel.dietaryConflicts(for: recipe, using: appState.members)
           │ computes set difference
           ▼
  conflicts: [String]
           │
    ┌──────┴──────┐
    │ empty       │ non-empty
    ▼             ▼
  no indicator  red border + red dot on slot cell
                long-press → "⚠️ Vegan, ⚠️ Jain"
```

## The computation

`MealPlanViewModel.dietaryConflicts(for:using:)` in `MealPlanViewModel.swift:107`:

```swift
func dietaryConflicts(for recipe: Recipe, using members: [Member]) -> [String] {
    let allRestrictions = Set(members.flatMap { $0.dietaryRestrictions })
    return allRestrictions.filter { !recipe.safeForTags.contains($0) }.sorted()
}
```

It unions all members' restrictions into a single set, then returns any restriction not covered by the recipe's `safe_for_tags`. This is conservative by design: a recipe must be explicitly tagged as safe for a restriction to be considered conflict-free. Absence of a tag is treated as a conflict.

## Why union, not intersection?

Using the union of all restrictions means: if ANY member can't eat it, the meal gets flagged. This is the correct behavior for a household meal planner — you can't cook two different dinners.

If the household had member A (Vegan) and member B (no restrictions), a non-vegan dinner is flagged because A can't eat it. B's lack of restrictions doesn't suppress A's conflict.

## Where member data comes from

`WeekGridView` reads `appState.members` (not `viewModel.members`), because `AppState` is updated synchronously when the user saves restriction edits in `HouseholdView`. If we read from `viewModel.members`, there would be an async gap at launch (members not yet fetched from DB) when the grid would render without any restriction data.

`AppState.applyLocalRestrictions()` overlays UserDefaults-cached member data on top of freshly fetched DB rows. This means restriction edits made on this device are always reflected in conflict detection, even before the Supabase write completes.

## Data path: setting a restriction

1. User opens Household tab → Member row → edit sheet
2. User toggles "Vegan" on
3. `HouseholdView` calls `appState.members[i].dietaryRestrictions = [...]`
4. `appState.saveLocalMemberData()` writes to UserDefaults
5. `HouseholdService.updateMember(...)` fire-and-forgets the DB write
6. `WeekGridView` is already observing `appState.members` via `@EnvironmentObject` → re-renders the grid → conflict dots appear/disappear

No re-fetch from Supabase is needed. The change propagates immediately through SwiftUI's observation system.

## Data path: the second phone

Member B's phone doesn't get a Realtime event for `members` row changes (only `meal_slots` are subscribed). Member B sees updated conflict indicators after:
- App relaunch (members re-fetched on `HouseholdView.onAppear`)
- Manual pull-to-refresh

A future improvement could subscribe to `members` changes via Realtime.

## Visual design

| Condition | Visual |
|---|---|
| Recipe is safe for all members | No indicator |
| One or more conflicts | Red 1px border + 6px red circle (top-right) |
| Slot has no recipe | No indicator |

The conflict list is shown in a long-press context menu, not inline — to avoid cluttering small slot cells.

## Related

- [Dietary Tags Reference](reference-dietary-tags.md)
- [How to Set Dietary Restrictions](howto-dietary-restrictions.md)
- [Architecture Overview](explanation-architecture.md) — why AppState.members instead of viewModel.members
