-- migrate:up
-- Enable UUID extension in PostgreSQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Add uuid column to existing table (nullable first, without breaking anything)
ALTER TABLE users
    ADD COLUMN uuid UUID DEFAULT gen_random_uuid();

-- Fill UUIDs for existing users
UPDATE users SET uuid = gen_random_uuid() WHERE uuid IS NULL;

-- Make column required and unique after filling all records
ALTER TABLE users
    ALTER COLUMN uuid SET NOT NULL,
    ADD CONSTRAINT users_uuid_unique UNIQUE (uuid);

-- Create index for uuid searches (will be the primary key in the future)
CREATE INDEX IF NOT EXISTS idx_users_uuid ON users(uuid);
-- migrate:down
DROP INDEX IF EXISTS idx_users_uuid;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_uuid_unique;
ALTER TABLE users DROP COLUMN IF EXISTS uuid;