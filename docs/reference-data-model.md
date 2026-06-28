# Data Model Reference

Meal Memory stores all data in Supabase (PostgreSQL). Every table has Row Level Security (RLS) enabled — a user can only read or write rows that belong to their household.

## Tables

### `households`

The top-level shared unit. Every recipe, meal slot, and member belongs to exactly one household.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `uuid` | `gen_random_uuid()` | Primary key |
| `name` | `text` | `'Our Household'` | Display name shown in the UI |
| `timezone` | `text` | `'Asia/Kolkata'` | IANA timezone string |
| `created_at` | `timestamptz` | `now()` | Creation timestamp |

---

### `members`

One row per user per household. Captures the person's display name, dietary restrictions, and APNs tokens for push notifications.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `uuid` | `gen_random_uuid()` | Primary key |
| `household_id` | `uuid` | — | FK → `households.id` (CASCADE delete) |
| `user_id` | `uuid` | — | FK → `auth.users.id` (CASCADE delete) |
| `display_name` | `text` | `''` | Human-readable name, auto-populated from email prefix on join |
| `dietary_restrictions` | `text[]` | `'{}'` | Array of restriction tags (see [Dietary Tags Reference](reference-dietary-tags.md)) |
| `apns_device_tokens` | `text[]` | `'{}'` | APNs device tokens for push prep alerts |
| `joined_at` | `timestamptz` | `now()` | When the user joined the household |

**Constraint:** `UNIQUE (household_id, user_id)` — a user can be in a household only once.

---

### `recipes`

The household's recipe collection. Recipes are shared: any member can read, create, update, or delete any recipe.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `uuid` | `gen_random_uuid()` | Primary key |
| `household_id` | `uuid` | — | FK → `households.id` (CASCADE delete) |
| `name` | `text` | — | Recipe name (required) |
| `emoji` | `text` | `'🍽'` | Single emoji representing the dish |
| `ingredients` | `text[]` | `'{}'` | Free-text ingredient list |
| `steps` | `jsonb` | `'[]'` | Array of `{text: string, hours_before: int}` objects |
| `safe_for_tags` | `text[]` | `'{}'` | Dietary tags this recipe is safe for (see [Dietary Tags](reference-dietary-tags.md)) |
| `prep_time_minutes` | `integer` | `null` | Active cooking/prep time in minutes; shown in the recipe row and detail view |
| `prep_night_before` | `boolean` | `false` | True when the recipe needs overnight prep (soaking, marinating, defrosting) — shows 🌙 in the plan grid |
| `source_url` | `text` | `null` | Original URL if imported |
| `photo_path` | `text` | `null` | Storage path: `{household_id}/{recipe_id}/photo.jpg` |
| `archived` | `boolean` | `false` | Soft-delete flag; archived recipes are hidden from the bank and plan picker |
| `created_by` | `uuid` | — | FK → `auth.users.id` |
| `created_at` | `timestamptz` | `now()` | Creation timestamp |
| `updated_at` | `timestamptz` | `now()` | Last update timestamp (auto-updated via trigger) |

**`steps` schema:** Each element is a JSON object:
```json
{ "text": "Boil water", "hours_before": 0 }
```
`hours_before > 0` means the step should be done N hours before the meal — used by the prep-alert system.

---

### `meal_slots`

One row per (household, date, meal-type) triple. This is the weekly plan. When a recipe is placed in a slot, `recipe_id` is set. When the slot is cleared, `recipe_id` is `null`.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `uuid` | `gen_random_uuid()` | Primary key |
| `household_id` | `uuid` | — | FK → `households.id` (CASCADE delete) |
| `slot_date` | `date` | — | The calendar date (ISO 8601) |
| `meal_type` | `meal_type` enum | — | `breakfast`, `lunch`, or `dinner` |
| `recipe_id` | `uuid` | `null` | FK → `recipes.id` (SET NULL on delete) |
| `updated_by` | `uuid` | `null` | FK → `auth.users.id` — last person to change the slot |
| `updated_at` | `timestamptz` | `now()` | Last update timestamp (auto-updated via trigger) |

**Constraint:** `UNIQUE (household_id, slot_date, meal_type)` — enforced at the DB level; the app upserts on conflict.

**Realtime:** `meal_slots` is published on the `supabase_realtime` channel. Both phones in a household receive INSERT and UPDATE events instantly.

---

### `invite_tokens`

Short-lived 6-character codes used to invite a second person into a household.

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `uuid` | `gen_random_uuid()` | Primary key |
| `household_id` | `uuid` | — | FK → `households.id` (CASCADE delete) |
| `token` | `text` | — | 6-char uppercase alphanumeric (no ambiguous chars: I, O, 0, 1) |
| `created_by` | `uuid` | — | FK → `auth.users.id` |
| `expires_at` | `timestamptz` | `now() + 48h` | Tokens expire after 48 hours |
| `used_at` | `timestamptz` | `null` | Set when claimed; prevents reuse |

---

## Storage

### `recipe-photos` bucket

Private storage bucket. Path convention: `{household_id}/{recipe_id}/photo.jpg`.

Members can read, upload, and delete photos only within their household's folder (enforced by storage RLS policies using `storage.foldername()`).

Signed URLs (1-hour expiry) are generated server-side for display — the bucket is never publicly accessible.

---

## Migrations

| File | Applied | Description |
|------|---------|-------------|
| `20260626000001_core_schema.sql` | ✅ | All tables, indexes, triggers |
| `20260626000002_rls_policies.sql` | ✅ | All RLS policies + storage policies |
| `20260626000003_fix_members_rls_recursion.sql` | ✅ | `my_household_id()` SECURITY DEFINER to break recursion |
| `20260627000001_recipe_archiving.sql` | ✅ | `archived` column on `recipes` |
| `20260628000001_recipe_prep_time.sql` | ⏳ apply before real mode | `prep_time_minutes` column on `recipes` |
| `20260628000002_recipe_prep_night_before.sql` | ⏳ apply before real mode | `prep_night_before` boolean on `recipes` |

## Related

- [RLS Security Model](explanation-rls-security.md)
- [Services Reference](reference-services.md)
- [Dietary Tags Reference](reference-dietary-tags.md)
