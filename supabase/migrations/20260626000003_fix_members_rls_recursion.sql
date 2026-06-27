-- Fix infinite recursion in members RLS policy.
-- The SELECT policy on members referenced members itself, causing a loop.
-- Solution: a SECURITY DEFINER function that bypasses RLS to get the
-- caller's household_id, then use it everywhere a self-join was needed.

CREATE OR REPLACE FUNCTION my_household_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT household_id FROM members WHERE user_id = auth.uid() LIMIT 1;
$$;

-- Drop and replace the recursive policy
DROP POLICY IF EXISTS "members can read household members" ON members;

CREATE POLICY "members can read household members"
  ON members FOR SELECT
  USING (household_id = my_household_id());

-- Also fix the other tables that had the same self-referential subquery pattern
DROP POLICY IF EXISTS "household members can read recipes" ON recipes;
DROP POLICY IF EXISTS "household members can create recipes" ON recipes;
DROP POLICY IF EXISTS "household members can update recipes" ON recipes;
DROP POLICY IF EXISTS "household members can delete recipes" ON recipes;

CREATE POLICY "household members can read recipes"
  ON recipes FOR SELECT
  USING (household_id = my_household_id());

CREATE POLICY "household members can create recipes"
  ON recipes FOR INSERT
  WITH CHECK (household_id = my_household_id() AND created_by = auth.uid());

CREATE POLICY "household members can update recipes"
  ON recipes FOR UPDATE
  USING (household_id = my_household_id());

CREATE POLICY "household members can delete recipes"
  ON recipes FOR DELETE
  USING (household_id = my_household_id());

DROP POLICY IF EXISTS "household members can read meal slots" ON meal_slots;
DROP POLICY IF EXISTS "household members can upsert meal slots" ON meal_slots;
DROP POLICY IF EXISTS "household members can update meal slots" ON meal_slots;
DROP POLICY IF EXISTS "household members can delete meal slots" ON meal_slots;

CREATE POLICY "household members can read meal slots"
  ON meal_slots FOR SELECT
  USING (household_id = my_household_id());

CREATE POLICY "household members can upsert meal slots"
  ON meal_slots FOR INSERT
  WITH CHECK (household_id = my_household_id());

CREATE POLICY "household members can update meal slots"
  ON meal_slots FOR UPDATE
  USING (household_id = my_household_id());

CREATE POLICY "household members can delete meal slots"
  ON meal_slots FOR DELETE
  USING (household_id = my_household_id());

DROP POLICY IF EXISTS "members can create invite tokens" ON invite_tokens;

CREATE POLICY "members can create invite tokens"
  ON invite_tokens FOR INSERT
  WITH CHECK (household_id = my_household_id());
