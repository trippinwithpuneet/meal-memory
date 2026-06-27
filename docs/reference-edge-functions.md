# Edge Functions Reference

Edge Functions run on Deno on Supabase's edge network. They bypass CORS restrictions that would block direct fetch calls from mobile apps, and they have access to server-side secrets.

Project ref: `dkxbtavoeqvixepwqutg`  
Base URL: `https://dkxbtavoeqvixepwqutg.supabase.co/functions/v1/`

All functions require a valid `Authorization: Bearer <jwt>` header.

---

## `fetch-recipe`

**Path:** `POST /functions/v1/fetch-recipe`  
**Source:** `supabase/functions/fetch-recipe/index.ts`  
**Status:** Deployed

Fetches a recipe page by URL and extracts structured data. Tries JSON-LD `schema.org/Recipe` first (~80% coverage on food blogs); falls back to OpenGraph `og:title`.

### Request

```json
{ "url": "https://example.com/my-recipe" }
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `url` | `string` | yes | Must be an HTTP or HTTPS URL |

### Response (200)

```json
{
  "name": "Dal Tadka",
  "ingredients": ["1 cup yellow lentils", "2 tbsp ghee", "..."],
  "steps": ["Rinse lentils", "Pressure cook for 3 whistles", "..."]
}
```

When only OpenGraph is available (no JSON-LD), `ingredients` and `steps` are empty arrays — the user fills them in manually.

### Error responses

| Status | Condition |
|--------|-----------|
| `400` | Invalid JSON body or non-HTTP/S URL |
| `401` | Missing or invalid `Authorization` header |
| `405` | Non-POST request |
| `422` | Page fetch failed or no recipe data found |
| `429` | Rate limit exceeded (1 import per 5 seconds per household) |

### Rate limiting

Server-side: in-memory per household, 5-second window. Client-side: `RecipeImportService` also enforces 5 seconds locally. Both limits reset on function cold-start.

---

## `delete-account`

**Path:** `POST /functions/v1/delete-account`  
**Source:** `supabase/functions/delete-account/index.ts`  
**Status:** Deployed

Deletes the calling user's account. If the user is the last member of their household, also deletes the household (cascades to all recipes and meal slots).

### Request

No body required. Auth token in header identifies the user.

### Response

- `200` — Account deleted
- `401` — Unauthorized

### iOS invocation

```swift
// From HouseholdView.deleteAccount()
let url = base.appendingPathComponent("functions/v1/delete-account")
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
```

---

## `leave-household`

**Path:** `POST /functions/v1/leave-household`  
**Source:** `supabase/functions/leave-household/index.ts`  
**Status:** Deployed (not yet wired to iOS UI)

Removes the calling user from their household without deleting the household or their account.

---

## `send-prep-alerts`

**Path:** `POST /functions/v1/send-prep-alerts`  
**Source:** `supabase/functions/send-prep-alerts/index.ts`  
**Status:** Deployed (APNs not yet configured)

Queries tomorrow's meal slots, finds recipes with `steps[].hours_before > 0`, and sends APNs push notifications to household members.

Intended to run via a Supabase cron schedule nightly at 9 PM IST.

---

## Deploying

```bash
export SUPABASE_ACCESS_TOKEN=<your-token>
cd /path/to/meal-memory

# Deploy one function
~/.local/share/supabase/supabase functions deploy fetch-recipe --project-ref dkxbtavoeqvixepwqutg

# Apply pending DB migrations
~/.local/share/supabase/supabase link --project-ref dkxbtavoeqvixepwqutg
~/.local/share/supabase/supabase db push --linked
```

## Related

- [Services Reference](reference-services.md) — `RecipeImportService` wraps `fetch-recipe`
- [How to Import a Recipe from a URL](howto-import-recipe-url.md)
