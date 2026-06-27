-- Row Level Security policies for all tables
-- Every table: enable RLS, then add explicit policies.
-- Default deny-all enforced by RLS; every access requires a matching policy.

-- ─── HOUSEHOLDS ──────────────────────────────────────────────────────────────
ALTER TABLE households ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members can read their household"
  ON households FOR SELECT
  USING (id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "authenticated users can create a household"
  ON households FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "members can update their household"
  ON households FOR UPDATE
  USING (id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

-- ─── MEMBERS ─────────────────────────────────────────────────────────────────
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members can read household members"
  ON members FOR SELECT
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "users can insert themselves as member"
  ON members FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "users can update their own member row"
  ON members FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "users can delete their own member row"
  ON members FOR DELETE
  USING (user_id = auth.uid());

-- ─── INVITE TOKENS ───────────────────────────────────────────────────────────
ALTER TABLE invite_tokens ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read unexpired+unclaimed tokens (needed to join)
CREATE POLICY "invite tokens readable to join"
  ON invite_tokens FOR SELECT
  USING (used_at IS NULL AND expires_at > now());

-- Only household members can create invite tokens for their household
CREATE POLICY "members can create invite tokens"
  ON invite_tokens FOR INSERT
  WITH CHECK (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

-- Anyone authenticated can claim (update used_at) an unclaimed token
CREATE POLICY "authenticated users can claim invite token"
  ON invite_tokens FOR UPDATE
  USING (used_at IS NULL AND expires_at > now())
  WITH CHECK (auth.uid() IS NOT NULL);

-- ─── RECIPES ─────────────────────────────────────────────────────────────────
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "household members can read recipes"
  ON recipes FOR SELECT
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "household members can create recipes"
  ON recipes FOR INSERT
  WITH CHECK (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid())
    AND created_by = auth.uid());

CREATE POLICY "household members can update recipes"
  ON recipes FOR UPDATE
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "household members can delete recipes"
  ON recipes FOR DELETE
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

-- ─── MEAL SLOTS ──────────────────────────────────────────────────────────────
ALTER TABLE meal_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "household members can read meal slots"
  ON meal_slots FOR SELECT
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "household members can upsert meal slots"
  ON meal_slots FOR INSERT
  WITH CHECK (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "household members can update meal slots"
  ON meal_slots FOR UPDATE
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

CREATE POLICY "household members can delete meal slots"
  ON meal_slots FOR DELETE
  USING (household_id IN (SELECT household_id FROM members WHERE user_id = auth.uid()));

-- ─── STORAGE: recipe-photos bucket ───────────────────────────────────────────
-- Bucket must be created via Supabase Dashboard or CLI (private, not public).
-- Path convention: {household_id}/{recipe_id}/photo.jpg
-- These policies use storage.foldername() to extract the household_id from path.

-- Allow household members to read photos from their household's folder
CREATE POLICY "household members can read recipe photos"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'recipe-photos'
    AND (storage.foldername(name))[1] IN (
      SELECT household_id::text FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "household members can upload recipe photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'recipe-photos'
    AND (storage.foldername(name))[1] IN (
      SELECT household_id::text FROM members WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "household members can delete recipe photos"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'recipe-photos'
    AND (storage.foldername(name))[1] IN (
      SELECT household_id::text FROM members WHERE user_id = auth.uid()
    )
  );
