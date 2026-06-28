-- Add night-before prep flag to recipes.
-- Replaces the dietary-conflict dot in the meal plan grid with a 🌙 indicator.

ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS prep_night_before BOOLEAN NOT NULL DEFAULT FALSE;
