# How to Archive a Recipe

Archiving removes a recipe from your Recipe Bank without permanently deleting it. Archived recipes are also hidden from the meal plan picker, so they won't clutter your weekly planning view.

Use archiving for recipes you've tried and don't plan to make again, or recipes you want to temporarily hide from the picker.

## Steps

1. Open the **Recipes** tab.
2. Find the recipe you want to archive.
3. Swipe left on the recipe row.
4. An **Archive** button (with a box icon) appears on the right.
5. Tap **Archive** (or complete the full swipe to the left — it auto-archives).

The recipe disappears from the list immediately.

## What archiving does

- Sets `archived = true` on the recipe in the database.
- The recipe no longer appears in:
  - The Recipe Bank list
  - The recipe picker on the Plan tab
- If the recipe was already assigned to a meal slot, **it stays in that slot** — archiving does not remove it from the current plan.

## What archiving does NOT do

- It does not delete the recipe. The data (name, ingredients, steps, photo) is preserved.
- It does not remove it from past or current meal slots.

## Restoring an archived recipe

There is currently no UI to restore archived recipes. To unarchive, use the Supabase dashboard:

1. Open the Supabase project dashboard.
2. Navigate to **Table Editor → recipes**.
3. Find the recipe (filter by `household_id` or `name`).
4. Set `archived = false`.

A future version will add an "Archived" toggle in the Recipe Bank.

## Related

- [RecipeService.setArchived](reference-services.md)
- [Data Model Reference — recipes](reference-data-model.md)
