# How to Set Dietary Restrictions and Understand Conflict Warnings

Dietary restrictions let Meal Memory warn you when a planned recipe isn't safe for everyone in the household.

## Setting a restriction

1. Open the **Household** tab.
2. Tap your name (or any member's name) in the member list.
3. A sheet slides up showing your display name and a list of dietary options.
4. Toggle any restrictions that apply to you.
5. Tap **Save**.

The change takes effect immediately — the week grid re-renders with updated conflict indicators without any additional reload.

## Available restrictions

| Tag | What it means |
|-----|--------------|
| Vegan | No animal products (meat, fish, dairy, eggs, honey) |
| Vegetarian | No meat or fish |
| Jain | No meat, fish, eggs, or root vegetables (onion, garlic, potato, carrot, beetroot) |
| No onion-garlic | No onion or garlic |
| Gluten-free | No wheat, barley, rye, or their derivatives |
| Dairy-free | No milk, cheese, butter, cream, or other dairy |

## Tagging a recipe as safe

When you create or edit a recipe:

1. Tap **Safe For** in the recipe form.
2. Select all dietary categories the recipe satisfies.
3. Save the recipe.

A recipe must be explicitly tagged for a restriction to be considered safe. If in doubt, don't tag it — the warning system is conservative by design.

## Reading conflict warnings

The week grid shows a small **red dot** (top-right corner) and a **red border** on any meal slot where the assigned recipe doesn't satisfy all household members' restrictions.

To see which restrictions conflict:

- **Long-press** the slot
- A context menu appears with warning lines: e.g. `⚠️ Vegan`, `⚠️ Dairy-free`

No indicator means the recipe is safe for everyone.

## Example

- Person A has: Vegan
- Person B has: Dairy-free
- A recipe is tagged: Vegetarian, Dairy-free

The union of restrictions is `{Vegan, Dairy-free}`. The recipe covers `Dairy-free` but not `Vegan`. Result: conflict warning appears on the slot.

To resolve it: either plan a different recipe, or update the recipe's dietary tags if you know it's actually vegan.

## Related

- [Dietary Tags Reference](reference-dietary-tags.md)
- [Conflict Detection Explanation](explanation-conflict-detection.md)
