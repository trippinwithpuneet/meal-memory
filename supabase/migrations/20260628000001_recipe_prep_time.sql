-- Add prep_time_minutes to recipes table
ALTER TABLE recipes ADD COLUMN IF NOT EXISTS prep_time_minutes INTEGER DEFAULT NULL;
