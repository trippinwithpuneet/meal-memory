-- Confine anonymous sessions to exactly what they exist for: calling the
-- fetch-recipe Edge Function so demo users can try URL import before signing up.
--
-- Enabling Anonymous Sign-ins means anonymous users carry the `authenticated`
-- role, so every grant and policy written for `authenticated` silently widened
-- to "anyone who opens the app". Reads are already safe — all household data is
-- gated on membership via auth.uid(), and an anonymous user has no member rows.
-- What did widen is the write surface:
--
--   (1) create_household()      — granted to authenticated → unlimited anonymous
--                                 sessions could spam household + member rows.
--   (2) redeem_invite_token()   — granted to authenticated → invite codes are
--                                 6 chars over a 32-char alphabet (~1.07e9), so
--                                 not realistically brute-forceable today, but
--                                 the barrier to trying was previously "own a
--                                 real account" and is now "tap a button".
--   (3) households INSERT policy — gated only on auth.uid() IS NOT NULL.
--
-- Supabase exposes an `is_anonymous` JWT claim; gate all three on it. Demo users
-- keep the anonymous session (and therefore import); anything that mutates the
-- household graph continues to require a real, signed-up account.

-- ── Helper: is the current caller an anonymous user? ────────────────────────
CREATE OR REPLACE FUNCTION is_anonymous_user()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false);
$$;

REVOKE ALL ON FUNCTION is_anonymous_user() FROM public;
GRANT EXECUTE ON FUNCTION is_anonymous_user() TO authenticated;

-- ── 1. Households may not be created by anonymous sessions ──────────────────
DROP POLICY IF EXISTS "authenticated users can create a household" ON households;
CREATE POLICY "authenticated users can create a household"
  ON households FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND NOT is_anonymous_user());

-- ── 2. create_household: reject anonymous callers ──────────────────────────
CREATE OR REPLACE FUNCTION create_household(p_name text, p_display_name text DEFAULT '')
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_household_id uuid := gen_random_uuid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING errcode = '28000';
  END IF;

  IF is_anonymous_user() THEN
    RAISE EXCEPTION 'anonymous users cannot create a household' USING errcode = '28000';
  END IF;

  INSERT INTO households (id, name) VALUES (v_household_id, p_name);

  INSERT INTO members (household_id, user_id, display_name)
  VALUES (v_household_id, v_uid, COALESCE(NULLIF(p_display_name, ''), ''));

  RETURN v_household_id;
END;
$$;

-- ── 3. redeem_invite_token: reject anonymous callers ───────────────────────
CREATE OR REPLACE FUNCTION redeem_invite_token(p_token text, p_display_name text DEFAULT '')
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_household_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING errcode = '28000';
  END IF;

  IF is_anonymous_user() THEN
    RAISE EXCEPTION 'anonymous users cannot redeem an invite' USING errcode = '28000';
  END IF;

  -- Lock the exact, unused, unexpired token
  SELECT household_id INTO v_household_id
  FROM invite_tokens
  WHERE token = upper(p_token)
    AND used_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF v_household_id IS NULL THEN
    RAISE EXCEPTION 'invalid or expired invite token' USING errcode = 'P0002';
  END IF;

  INSERT INTO members (household_id, user_id, display_name)
  VALUES (v_household_id, v_uid, COALESCE(NULLIF(p_display_name, ''), ''))
  ON CONFLICT (household_id, user_id) DO NOTHING;

  UPDATE invite_tokens SET used_at = now()
  WHERE token = upper(p_token) AND used_at IS NULL;

  RETURN v_household_id;
END;
$$;

REVOKE ALL ON FUNCTION create_household(text, text)     FROM public;
REVOKE ALL ON FUNCTION redeem_invite_token(text, text)  FROM public;
GRANT EXECUTE ON FUNCTION create_household(text, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION redeem_invite_token(text, text) TO authenticated;
