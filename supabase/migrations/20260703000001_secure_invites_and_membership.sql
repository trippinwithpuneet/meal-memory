-- Security fix: two related holes in the invite / membership model.
--
--  (1) invite_tokens SELECT policy "invite tokens readable to join" used
--      `USING (used_at IS NULL AND expires_at > now())`, so ANY authenticated
--      user could read EVERY active invite token across ALL households and
--      enumerate/redeem them.
--  (2) members INSERT policy "users can insert themselves as member" used
--      `WITH CHECK (user_id = auth.uid())` with no household gate, so any user
--      could insert themselves into ANY household id, invite or not.
--
-- Fix: membership changes go exclusively through SECURITY DEFINER functions
-- that validate server-side. Clients no longer read invite tokens broadly or
-- insert member rows directly.

-- ── 1. Remove the enumerable / permissive policies ──────────────────────────
DROP POLICY IF EXISTS "invite tokens readable to join" ON invite_tokens;
DROP POLICY IF EXISTS "authenticated users can claim invite token" ON invite_tokens;
DROP POLICY IF EXISTS "users can insert themselves as member" ON members;

-- ── 2. Members may read only their OWN household's invite tokens ─────────────
-- (no cross-household enumeration). Redemption does not depend on this.
DROP POLICY IF EXISTS "members can read own household invite tokens" ON invite_tokens;
CREATE POLICY "members can read own household invite tokens"
  ON invite_tokens FOR SELECT
  USING (household_id = my_household_id());

-- ── 3. Create a household + add the creator, atomically, as definer ─────────
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

  INSERT INTO households (id, name) VALUES (v_household_id, p_name);

  INSERT INTO members (household_id, user_id, display_name)
  VALUES (v_household_id, v_uid, COALESCE(NULLIF(p_display_name, ''), ''));

  RETURN v_household_id;
END;
$$;

-- ── 4. Redeem an invite token: exact match, server-validated, atomic ────────
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

  -- Add the caller as a member (idempotent on household+user)
  INSERT INTO members (household_id, user_id, display_name)
  VALUES (v_household_id, v_uid, COALESCE(NULLIF(p_display_name, ''), ''))
  ON CONFLICT (household_id, user_id) DO NOTHING;

  -- Burn the token
  UPDATE invite_tokens SET used_at = now()
  WHERE token = upper(p_token) AND used_at IS NULL;

  RETURN v_household_id;
END;
$$;

-- ── 5. Grants: authenticated users may call the functions, nothing else ─────
REVOKE ALL ON FUNCTION create_household(text, text)     FROM public;
REVOKE ALL ON FUNCTION redeem_invite_token(text, text)  FROM public;
GRANT EXECUTE ON FUNCTION create_household(text, text)    TO authenticated;
GRANT EXECUTE ON FUNCTION redeem_invite_token(text, text) TO authenticated;
