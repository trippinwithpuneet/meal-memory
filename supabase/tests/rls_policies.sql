-- pgTAP RLS tests — run with: supabase test db
-- Requires pg_prove or supabase test db

BEGIN;
SELECT plan(16);

-- ─── Setup ───────────────────────────────────────────────────────────────────
-- Create two test households and two users
INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('00000000-0000-0000-0000-000000000002', 'bob@test.com');

INSERT INTO households (id, name) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Household'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Bob Household');

INSERT INTO members (household_id, user_id, display_name) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Alice'),
  ('bbbbbbbb-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Bob');

INSERT INTO recipes (id, household_id, name, emoji, created_by) VALUES
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Dal Makhani', '🫕', '00000000-0000-0000-0000-000000000001'),
  ('dddddddd-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Chicken Curry', '🍛', '00000000-0000-0000-0000-000000000002');

-- ─── Member isolation: recipes ───────────────────────────────────────────────
SET LOCAL role = authenticated;
SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000001"}';

SELECT is(
  (SELECT count(*)::int FROM recipes WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1,
  'Alice can read her own household recipes'
);

SELECT is(
  (SELECT count(*)::int FROM recipes WHERE household_id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  0,
  'Alice cannot read Bob''s household recipes'
);

-- ─── Member isolation: meal_slots ────────────────────────────────────────────
INSERT INTO meal_slots (household_id, slot_date, meal_type, recipe_id)
  VALUES ('aaaaaaaa-0000-0000-0000-000000000001', current_date, 'lunch', 'cccccccc-0000-0000-0000-000000000001');

SELECT is(
  (SELECT count(*)::int FROM meal_slots WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1,
  'Alice can read her household meal slots'
);

SELECT is(
  (SELECT count(*)::int FROM meal_slots WHERE household_id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  0,
  'Alice cannot read Bob''s meal slots'
);

-- ─── Invite token: readable when unexpired + unused ──────────────────────────
INSERT INTO invite_tokens (household_id, token, created_by, expires_at) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'ABC123', '00000000-0000-0000-0000-000000000001', now() + interval '24 hours');

SELECT is(
  (SELECT count(*)::int FROM invite_tokens WHERE token = 'ABC123'),
  1,
  'Unexpired+unclaimed invite token is readable'
);

-- ─── Invite token: NOT readable when expired ─────────────────────────────────
INSERT INTO invite_tokens (household_id, token, created_by, expires_at) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'EXPIRED', '00000000-0000-0000-0000-000000000001', now() - interval '1 hour');

SELECT is(
  (SELECT count(*)::int FROM invite_tokens WHERE token = 'EXPIRED'),
  0,
  'Expired invite token is NOT readable'
);

-- ─── Invite token: NOT readable when already used ────────────────────────────
INSERT INTO invite_tokens (household_id, token, created_by, expires_at, used_at) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'USED123', '00000000-0000-0000-0000-000000000001', now() + interval '24 hours', now() - interval '5 minutes');

SELECT is(
  (SELECT count(*)::int FROM invite_tokens WHERE token = 'USED123'),
  0,
  'Already-used invite token is NOT readable'
);

-- ─── Invite token: household member can create token ─────────────────────────
SELECT lives_ok(
  $$ INSERT INTO invite_tokens (household_id, token, created_by) VALUES
       ('aaaaaaaa-0000-0000-0000-000000000001', 'NEW001', '00000000-0000-0000-0000-000000000001') $$,
  'Household member can create invite token for their household'
);

-- ─── Invite token: non-member CANNOT create token for other household ─────────
SELECT throws_ok(
  $$ INSERT INTO invite_tokens (household_id, token, created_by) VALUES
       ('bbbbbbbb-0000-0000-0000-000000000002', 'HACK01', '00000000-0000-0000-0000-000000000001') $$,
  'new row violates row-level security policy for table "invite_tokens"',
  'Non-member cannot create invite token for Bob''s household'
);

-- ─── Bob isolation ───────────────────────────────────────────────────────────
SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000002"}';

SELECT is(
  (SELECT count(*)::int FROM recipes WHERE household_id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  1,
  'Bob can read his own household recipes'
);

SELECT is(
  (SELECT count(*)::int FROM recipes WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'Bob cannot read Alice''s recipes'
);

-- ─── Recipe insert: member can insert for own household ──────────────────────
SELECT lives_ok(
  $$ INSERT INTO recipes (household_id, name, emoji, created_by) VALUES
       ('bbbbbbbb-0000-0000-0000-000000000002', 'Biryani', '🍚', '00000000-0000-0000-0000-000000000002') $$,
  'Bob can add recipe to his household'
);

-- ─── Recipe insert: member CANNOT insert for other household ─────────────────
SELECT throws_ok(
  $$ INSERT INTO recipes (household_id, name, emoji, created_by) VALUES
       ('aaaaaaaa-0000-0000-0000-000000000001', 'Hack Recipe', '💀', '00000000-0000-0000-0000-000000000002') $$,
  'new row violates row-level security policy for table "recipes"',
  'Bob cannot add recipe to Alice''s household'
);

-- ─── Meal slot upsert: member can write to own household ─────────────────────
SELECT lives_ok(
  $$ INSERT INTO meal_slots (household_id, slot_date, meal_type)
       VALUES ('bbbbbbbb-0000-0000-0000-000000000002', current_date, 'dinner') $$,
  'Bob can write meal slot in his household'
);

-- ─── Meal slot upsert: member CANNOT write to other household ─────────────────
SELECT throws_ok(
  $$ INSERT INTO meal_slots (household_id, slot_date, meal_type)
       VALUES ('aaaaaaaa-0000-0000-0000-000000000001', current_date + 1, 'dinner') $$,
  'new row violates row-level security policy for table "meal_slots"',
  'Bob cannot write meal slot in Alice''s household'
);

-- ─── Members: user can read their household members ──────────────────────────
SELECT is(
  (SELECT count(*)::int FROM members WHERE household_id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  1,
  'Bob can read members in his household'
);

SELECT is(
  (SELECT count(*)::int FROM members WHERE household_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'Bob cannot read members in Alice''s household'
);

SELECT * FROM finish();
ROLLBACK;
