-- migrate:up
-- Habilita extensão de UUID no PostgreSQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Adiciona coluna uuid na tabela existente (nullable primeiro, sem quebrar nada)
ALTER TABLE users
    ADD COLUMN uuid UUID DEFAULT gen_random_uuid();

-- Preenche UUIDs para usuários já existentes
UPDATE users SET uuid = gen_random_uuid() WHERE uuid IS NULL;

-- Torna a coluna obrigatória e única após preencher todos os registros
ALTER TABLE users
    ALTER COLUMN uuid SET NOT NULL,
    ADD CONSTRAINT users_uuid_unique UNIQUE (uuid);

-- Cria índice para buscas por uuid (será a chave principal futura)
CREATE INDEX IF NOT EXISTS idx_users_uuid ON users(uuid);
-- migrate:down
DROP INDEX IF EXISTS idx_users_uuid;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_uuid_unique;
ALTER TABLE users DROP COLUMN IF EXISTS uuid;