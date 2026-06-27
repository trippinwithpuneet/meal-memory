# How to Import a Recipe from a URL

Meal Memory can import recipe details directly from food blog URLs. This works for most major recipe sites that publish `schema.org/Recipe` JSON-LD markup (Serious Eats, Smitten Kitchen, Budget Bytes, NYT Cooking, etc.).

## Steps

1. Open the **Recipes** tab.
2. Tap the **+** button (top right) to open the Add Recipe sheet.
3. Tap **Import from URL** at the top of the sheet.
4. Paste or type the recipe URL into the text field.
5. Tap **Import**.
6. If the import succeeds, the Name, Ingredients, and Steps fields are pre-filled.
7. Review and edit the imported data as needed.
8. Add an **emoji** and any **dietary tags** (these are never auto-imported).
9. Tap **Save**.

## What gets imported

| Field | Imported? | Notes |
|-------|-----------|-------|
| Name | Yes | From JSON-LD `name` or OpenGraph `og:title` |
| Ingredients | Yes (if JSON-LD) | Plain-text strings, one per line |
| Steps | Yes (if JSON-LD) | Step text only; `hours_before` defaults to 0 |
| Emoji | No | Always set manually |
| Dietary tags | No | Always set manually |
| Photo | No | Must be added manually after saving |

## Why some imports are partial

Not all recipe sites publish JSON-LD. If a site uses only basic HTML or OpenGraph tags, only the recipe name is imported. The ingredient and step fields will be empty — you fill them in manually.

Pinterest URLs are a redirect (they link to the original blog). The app automatically follows the redirect to the target page.

## Rate limit

You can import one recipe per 5 seconds. Tapping Import again within 5 seconds shows "Rate limited — wait a moment."

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Could not fetch that URL" | Page is behind a paywall or rate-limit | Copy the URL from the site's share button, not the browser address bar |
| "No recipe data found" | Site doesn't publish JSON-LD or OpenGraph | Import the name manually, add ingredients yourself |
| Fields don't pre-fill | Site uses non-standard markup | The import got a name only; fill in the rest |
| Import button is greyed out | No URL entered yet | Type or paste a URL first |

## Related

- [Edge Functions Reference — fetch-recipe](reference-edge-functions.md)
- [Tutorial: Getting Started](tutorial-getting-started.md)
