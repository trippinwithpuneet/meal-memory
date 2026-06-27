-- Core schema for Meal Memory V1
-- Run order: this file first, then 002_rls.sql

-- ─── HOUSEHOLDS ──────────────────────────────────────────────────────────────
CREATE TABLE households (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL DEFAULT 'Our Household',
  timezone   text NOT NULL DEFAULT 'Asia/Kolkata',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ─── MEMBERS ─────────────────────────────────────────────────────────────────
CREATE TABLE members (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id         uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id              uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name         text NOT NULL DEFAULT '',
  dietary_restrictions text[] NOT NULL DEFAULT '{}',
  apns_device_tokens   text[] NOT NULL DEFAULT '{}',
  joined_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, user_id)
);

CREATE INDEX members_user_id_idx ON members(user_id);
CREATE INDEX members_household_id_idx ON members(household_id);

-- ─── INVITE TOKENS ───────────────────────────────────────────────────────────
CREATE TABLE invite_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  token        text NOT NULL UNIQUE,
  created_by   uuid NOT NULL REFERENCES auth.users(id),
  expires_at   timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  used_at      timestamptz
);

CREATE INDEX invite_tokens_token_idx ON invite_tokens(token);

-- ─── RECIPES ─────────────────────────────────────────────────────────────────
CREATE TABLE recipes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  name         text NOT NULL,
  emoji        text NOT NULL DEFAULT '🍽',
  ingredients  text[] NOT NULL DEFAULT '{}',
  steps        jsonb NOT NULL DEFAULT '[]',  -- [{text: string, hours_before: int}]
  safe_for_tags text[] NOT NULL DEFAULT '{}',
  source_url   text,
  photo_path   text,   -- storage path: household_id/recipe_id/photo.jpg
  created_by   uuid NOT NULL REFERENCES auth.users(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX recipes_household_id_idx ON recipes(household_id);

-- ─── MEAL SLOTS ──────────────────────────────────────────────────────────────
-- One row per (household, date, meal_type). Upsert on conflict.
CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner');

CREATE TABLE meal_slots (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  slot_date    date NOT NULL,
  meal_type    meal_type NOT NULL,
  recipe_id    uuid REFERENCES recipes(id) ON DELETE SET NULL,
  updated_by   uuid REFERENCES auth.users(id),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, slot_date, meal_type)
);

CREATE INDEX meal_slots_household_date_idx ON meal_slots(household_id, slot_date);

-- ─── UPDATED_AT TRIGGER ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER recipes_updated_at
  BEFORE UPDATE ON recipes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER meal_slots_updated_at
  BEFORE UPDATE ON meal_slots
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
