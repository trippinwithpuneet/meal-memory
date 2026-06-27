-- Add soft-delete support to recipes.
-- Archived recipes are hidden from the picker and recipe bank by default.

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE;

-- Index so filtering on archived is fast (most queries exclude archived rows).
CREATE INDEX IF NOT EXISTS idx_recipes_household_archived
    ON recipes (household_id, archived);
