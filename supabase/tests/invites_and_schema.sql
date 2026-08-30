-- pgTAP evals — invite security, membership integrity, and migration drift.
-- Run with: supabase test db   (needs Docker + the local Supabase stack)
--
-- Companion to rls_policies.sql, which covers cross-household read/write
-- isolation. This file covers what that one doesn't:
--
--   1. Migration drift — columns the app decodes must actually exist. Two
--      migrations (prep_time, prep_night_before) are recorded as unapplied in
--      CLAUDE.md, so these assertions are the check for that.
--   2. The SECURITY DEFINER invite path added in 20260703000001, which is the
--      only way membership can change. Its single-use, expiry, and
--      authentication rules are the app's main privilege-escalation surface.
--   3. Recipe archiving semantics.
--
-- NOTE: this file has not been executed — Docker was unavailable on the machine
-- where it was written, so treat the first run as a bring-up, not a regression.

BEGIN;
SELECT plan(23);

-- ─── Setup ───────────────────────────────────────────────────────────────────

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('00000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('00000000-0000-0000-0000-000000000003', 'carol@test.com');

INSERT INTO households (id, name) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Household'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Bob Household');

INSERT INTO members (household_id, user_id, display_name) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Alice'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Bob');

-- Three tokens for Alice's household: one live, one expired, one already used.
INSERT INTO invite_tokens (household_id, token, created_by, expires_at, used_at) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'LIVE01',
   '00000000-0000-0000-0000-000000000001', now() + interval '7 days', NULL),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'EXPIR1',
   '00000000-0000-0000-0000-000000000001', now() - interval '1 day', NULL),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'USED01',
   '00000000-0000-0000-0000-000000000001', now() + interval '7 days', now());

-- ─── 1. Migration drift: columns the app's decoder expects ───────────────────
-- Recipe.init(from:) tolerates the two prep columns being absent, but the app
-- silently loses the feature. These assertions make that visible.

SELECT has_column('public', 'recipes', 'archived',          'recipes.archived exists (migration 004)');
SELECT has_column('public', 'recipes', 'prep_time_minutes', 'recipes.prep_time_minutes exists (migration 20260628000001)');
SELECT has_column('public', 'recipes', 'prep_night_before', 'recipes.prep_night_before exists (migration 20260628000002)');
SELECT has_column('public', 'recipes', 'source_url',        'recipes.source_url exists (needed before source-link UI ships)');

-- ─── 2. The SECURITY DEFINER membership functions exist ──────────────────────

SELECT has_function('public', 'create_household',     'create_household() exists');
SELECT has_function('public', 'redeem_invite_token',  'redeem_invite_token() exists');

-- ─── 3. Execute grants are locked down ───────────────────────────────────────
-- Migration 20260703000001 revokes from public and grants only to authenticated.

SELECT ok(
  NOT has_function_privilege('anon', 'public.redeem_invite_token(text,text)', 'EXECUTE'),
  'anon cannot execute redeem_invite_token'
);
SELECT ok(
  has_function_privilege('authenticated', 'public.redeem_invite_token(text,text)', 'EXECUTE'),
  'authenticated can execute redeem_invite_token'
);

-- ─── 4. Redemption requires authentication ───────────────────────────────────

SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{}';

SELECT throws_ok(
  $$ SELECT redeem_invite_token('LIVE01', 'Nobody') $$,
  'not authenticated',
  'redeem_invite_token refuses an unauthenticated caller'
);

-- ─── 5. Redemption rejects bad, expired, and spent tokens ────────────────────

SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000003"}';

SELECT throws_ok(
  $$ SELECT redeem_invite_token('NOSUCH', 'Carol') $$,
  'invalid or expired invite token',
  'a token that never existed is rejected'
);

SELECT throws_ok(
  $$ SELECT redeem_invite_token('EXPIR1', 'Carol') $$,
  'invalid or expired invite token',
  'an expired token is rejected'
);

SELECT throws_ok(
  $$ SELECT redeem_invite_token('USED01', 'Carol') $$,
  'invalid or expired invite token',
  'an already-used token is rejected'
);

-- ─── 6. A valid token admits the caller, once ────────────────────────────────

SELECT is(
  (SELECT redeem_invite_token('live01', 'Carol')),
  'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
  'a live token admits the caller and is matched case-insensitively'
);

SELECT is(
  (SELECT count(*)::int FROM members
    WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'
      AND user_id = '00000000-0000-0000-0000-000000000003'),
  1,
  'redemption inserted exactly one membership row'
);

SET LOCAL role = postgres;
SELECT isnt(
  (SELECT used_at FROM invite_tokens WHERE token = 'LIVE01'),
  NULL,
  'the token is burned on redemption'
);

SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000003"}';
SELECT throws_ok(
  $$ SELECT redeem_invite_token('LIVE01', 'Carol again') $$,
  'invalid or expired invite token',
  'a token cannot be redeemed twice'
);

-- ─── 7. Membership cannot be granted by writing the table directly ───────────
-- The whole point of routing through SECURITY DEFINER functions: a user must
-- not be able to add themselves to a household they were never invited to.

SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000002"}';
SELECT throws_ok(
  $$ INSERT INTO members (household_id, user_id, display_name)
       VALUES ('aaaaaaaa-0000-0000-0000-000000000001',
               '00000000-0000-0000-0000-000000000002', 'Bob sneaking in') $$,
  'new row violates row-level security policy for table "members"',
  'a user cannot insert themselves into another household'
);

-- ─── 8. Invite tokens are readable only inside their own household ───────────

SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000001"}';
SELECT is(
  (SELECT count(*)::int FROM invite_tokens
    WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  3,
  'Alice can read her own household invite tokens'
);

SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000002"}';
SELECT is(
  (SELECT count(*)::int FROM invite_tokens
    WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'Bob cannot read another household''s invite tokens (no code harvesting)'
);

-- ─── 9. Recipe archiving ─────────────────────────────────────────────────────

SELECT lives_ok(
  $$ INSERT INTO recipes (id, household_id, name, emoji, created_by)
       VALUES ('eeeeeeee-0000-0000-0000-000000000001',
               'bbbbbbbb-0000-0000-0000-000000000002', 'Test Dish', '🍲',
               '00000000-0000-0000-0000-000000000002') $$,
  'a household member can create a recipe'
);

SELECT is(
  (SELECT archived FROM recipes WHERE id = 'eeeeeeee-0000-0000-0000-000000000001'),
  false,
  'new recipes are not archived by default'
);

SELECT is(
  (SELECT prep_night_before FROM recipes WHERE id = 'eeeeeeee-0000-0000-0000-000000000001'),
  false,
  'prep_night_before defaults to false, matching the Swift decoder default'
);

SELECT lives_ok(
  $$ UPDATE recipes SET archived = true
       WHERE id = 'eeeeeeee-0000-0000-0000-000000000001' $$,
  'archiving is an update the owning household can perform'
);

SELECT * FROM finish();
ROLLBACK;
