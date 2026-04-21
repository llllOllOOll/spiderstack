-- migrate:up
-- Tabela de identidades (suporta múltiplos providers por usuário)
CREATE TABLE IF NOT EXISTS user_identities (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_uuid          UUID NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
    provider           TEXT NOT NULL,          -- 'google' | 'email'
    provider_user_id   TEXT,                   -- google_id para OAuth, NULL para email
    password_hash      TEXT,                   -- bcrypt hash, NULL para OAuth
    created_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(provider, provider_user_id),
    UNIQUE(user_uuid, provider)
);

CREATE INDEX IF NOT EXISTS idx_user_identities_user_uuid ON user_identities(user_uuid);
CREATE INDEX IF NOT EXISTS idx_user_identities_provider  ON user_identities(provider, provider_user_id);

-- Tabela de roles
CREATE TABLE IF NOT EXISTS roles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL UNIQUE,          -- 'admin' | 'editor' | 'viewer'
    description TEXT,
    is_default  BOOLEAN DEFAULT false,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Roles padrão do sistema
INSERT INTO roles (name, description, is_default) VALUES
    ('admin',  'Acesso total ao sistema',       false),
    ('editor', 'Pode criar e editar conteúdo',  false),
    ('viewer', 'Apenas leitura',                true)
ON CONFLICT (name) DO NOTHING;

-- Tabela pivot: usuário <-> role
CREATE TABLE IF NOT EXISTS user_roles (
    user_uuid  UUID NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
    role_id    UUID NOT NULL REFERENCES roles(id)   ON DELETE CASCADE,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_uuid, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_uuid ON user_roles(user_uuid);

-- Tabela de permissões por role
CREATE TABLE IF NOT EXISTS role_permissions (
    role_id    UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission TEXT NOT NULL,                  -- formato: 'recurso:acao'
    PRIMARY KEY (role_id, permission)
);

-- Permissões padrão por role
INSERT INTO role_permissions (role_id, permission)
SELECT r.id, p.permission
FROM roles r
CROSS JOIN (VALUES
    ('admin',  'users:manage'),
    ('admin',  'billing:manage'),
    ('admin',  'settings:write'),
    ('admin',  'reports:read'),
    ('admin',  'content:write'),
    ('admin',  'content:delete'),
    ('editor', 'content:write'),
    ('editor', 'content:delete'),
    ('editor', 'reports:read'),
    ('editor', 'settings:read'),
    ('viewer', 'content:read'),
    ('viewer', 'reports:read'),
    ('viewer', 'profile:read')
) AS p(role_name, permission)
WHERE r.name = p.role_name
ON CONFLICT DO NOTHING;

-- Coluna tenant_id na tabela users (nullable — multitenancy opcional)
ALTER TABLE users ADD COLUMN IF NOT EXISTS tenant_id UUID DEFAULT NULL;
-- migrate:down
ALTER TABLE users DROP COLUMN IF EXISTS tenant_id;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS user_identities;