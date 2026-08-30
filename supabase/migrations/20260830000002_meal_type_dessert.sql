-- Add a fourth meal type: dessert.
--
-- meal_type is a Postgres ENUM, and Postgres cannot REMOVE a value from an enum.
-- Reversing this means recreating the type and rewriting every meal_slots row,
-- so treat it as one-way.
--
-- ALTER TYPE ... ADD VALUE is allowed inside a transaction on PG12+ (this project
-- is on PG17) provided the new value isn't *used* in the same transaction. This
-- migration only adds it — nothing here inserts a 'dessert' row — so it is safe
-- under `supabase db push`, which wraps migrations in a transaction.
--
-- IF NOT EXISTS keeps it idempotent, matching every other migration here.

ALTER TYPE meal_type ADD VALUE IF NOT EXISTS 'dessert';
