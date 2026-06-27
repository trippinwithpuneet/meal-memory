# Dietary Tags Reference

Dietary tags are string identifiers used in two places:

- **`members.dietary_restrictions`** — the restrictions a person has (what they cannot eat)
- **`recipes.safe_for_tags`** — the restrictions a recipe satisfies (what it is safe for)

A **conflict** occurs when a member has a restriction that is NOT in a recipe's `safe_for_tags`. Conflicting recipes show a red dot and red border in the week grid.

## Supported Tags

| Tag | Meaning |
|-----|---------|
| `Vegan` | Contains no animal products (no meat, fish, dairy, eggs, honey) |
| `Vegetarian` | Contains no meat or fish; dairy and eggs are permitted |
| `Jain` | No meat, fish, eggs, root vegetables (onion, garlic, potato, carrot, beetroot) |
| `No onion-garlic` | No onion or garlic; otherwise unrestricted |
| `Gluten-free` | No wheat, barley, rye, or their derivatives |
| `Dairy-free` | No milk, cheese, butter, cream, or other dairy products |

## How Conflict Detection Works

At render time, `MealPlanViewModel.dietaryConflicts(for:using:)` computes the union of all members' restrictions, then returns any restriction not found in the recipe's `safe_for_tags`:

```swift
func dietaryConflicts(for recipe: Recipe, using members: [Member]) -> [String] {
    let allRestrictions = Set(members.flatMap { $0.dietaryRestrictions })
    return allRestrictions.filter { !recipe.safeForTags.contains($0) }.sorted()
}
```

**Example:** A household has members with `["Vegan"]` and `["Jain"]`. A recipe has `safe_for_tags: ["Vegetarian", "Jain"]`. The union is `{"Vegan", "Jain"}`. `"Jain"` is covered; `"Vegan"` is not → conflict reported.

## Conflict UI

- **Red border + red dot** (top-right corner of slot cell) — one or more conflicts
- **Context menu** — long-press the slot to see exactly which restrictions conflict (e.g. "⚠️ Vegan")
- **No indicator** — recipe is safe for all household members

## Adding Custom Tags

The current tag set is defined in `MemberEditSheet.allRestrictions` in `HouseholdView.swift`:

```swift
private let allRestrictions = ["Vegan", "Vegetarian", "Jain", "No onion-garlic", "Gluten-free", "Dairy-free"]
```

To add a new tag: add it to this array. No DB migration required — tags are stored as plain text arrays.

## Related

- [How to Set Dietary Restrictions](howto-dietary-restrictions.md)
- [Conflict Detection Explanation](explanation-conflict-detection.md)
- [Data Model Reference](reference-data-model.md)
