# Row Level Security Model

Every Supabase table in Meal Memory has RLS enabled. A user can only read, insert, update, or delete rows that belong to their household.

## The core invariant

**A user can only access data that belongs to a household they are a member of.**

This is enforced at the database level by PostgreSQL RLS policies, not in application code. Even if a client bypasses the iOS app and calls the PostgREST API directly with a valid JWT, they cannot access another household's data.

## The membership check

All policies rely on a helper function `my_household_id()`:

```sql
CREATE OR REPLACE FUNCTION my_household_id()
RETURNS uuid LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT household_id FROM members WHERE user_id = auth.uid() LIMIT 1;
$$;
```

`SECURITY DEFINER` means it runs with the function owner's privileges (elevated), not the caller's. This is intentional: querying `members` to find your own household ID would otherwise cause infinite recursion (the `members` SELECT policy itself calls the membership check).

## Policies by table

### `households`

```sql
SELECT: id = my_household_id()
INSERT: id = my_household_id()   -- only after joining (or creating)
UPDATE: id = my_household_id()
DELETE: disabled                 -- households are never hard-deleted (only via cascade)
```

### `members`

```sql
SELECT: household_id = my_household_id()
INSERT: household_id = my_household_id() AND user_id = auth.uid()  -- can only insert yourself
UPDATE: household_id = my_household_id()  -- any member can edit any member's display name/restrictions
DELETE: disabled (use leave-household Edge Function)
```

The INSERT restriction `user_id = auth.uid()` ensures a user can only add themselves as a member, never add someone else.

### `recipes`

```sql
SELECT: household_id = my_household_id()
INSERT: household_id = my_household_id()
UPDATE: household_id = my_household_id()
DELETE: household_id = my_household_id()
```

Any member can create, read, update (including archive), and delete any recipe in the household.

### `meal_slots`

```sql
SELECT: household_id = my_household_id()
INSERT: household_id = my_household_id()
UPDATE: household_id = my_household_id()
DELETE: household_id = my_household_id()
```

Any member can place, move, and clear any meal slot in the household.

### `invite_tokens`

```sql
SELECT: household_id = my_household_id()   -- only your own household's tokens
INSERT: household_id = my_household_id()   -- only for your household
UPDATE: disabled (tokens are claimed via Edge Function with elevated access)
DELETE: disabled
```

The claim flow (joining via a token) is handled in `HouseholdService.claimInviteToken()`, which calls `supabase.from("members").insert(...)`. This INSERT is allowed by the `members` INSERT policy because the new member is inserting themselves.

### Storage (`recipe-photos` bucket)

```sql
SELECT: bucket_id = 'recipe-photos' AND (storage.foldername(name))[1] = my_household_id()::text
INSERT: same
UPDATE: same
DELETE: same
```

Photo paths follow `{household_id}/{recipe_id}/photo.jpg`. The policy checks that the first path component matches the user's household UUID.

## What the policies do NOT protect

- **Within-household privacy:** All members of a household share full access to all data. There is no per-member permission model — any member can edit any other member's display name or dietary restrictions.
- **Invite token secrecy:** Any member can see all their household's invite tokens (SELECT policy). Tokens expire in 48 hours and can only be used once.
- **Member enumeration:** Any authenticated user can call `my_household_id()` — but it returns `null` if they're not yet in a household, which causes all policies to fail, returning empty results.

## RLS recursion fix (migration 003)

The naive implementation of `members` SELECT policy was:

```sql
-- BROKEN — infinite recursion
SELECT: household_id = (SELECT household_id FROM members WHERE user_id = auth.uid())
```

This causes infinite recursion: selecting from `members` triggers the policy, which selects from `members`, ad infinitum.

The fix (`20260626000003_fix_members_rls_recursion.sql`) creates `my_household_id()` as `SECURITY DEFINER`, which bypasses RLS when executing, breaking the cycle.

## Related

- [Data Model Reference](reference-data-model.md)
- [Architecture Overview](explanation-architecture.md)
