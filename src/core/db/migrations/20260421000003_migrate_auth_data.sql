-- migrate:up
BEGIN;

-- Migrate all users with google_id to user_identities
INSERT INTO user_identities (user_uuid, provider, provider_user_id, created_at)
SELECT
    u.uuid,
    'google',
    u.google_id,
    u.created_at
FROM users u
WHERE u.google_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Assign 'viewer' role (default) to all existing users
INSERT INTO user_roles (user_uuid, role_id)
SELECT
    u.uuid,
    r.id
FROM users u
CROSS JOIN roles r
WHERE r.is_default = true
ON CONFLICT DO NOTHING;

COMMIT;
-- migrate:down
BEGIN;
DELETE FROM user_roles WHERE role_id IN (SELECT id FROM roles WHERE is_default = true);
DELETE FROM user_identities WHERE provider = 'google';
COMMIT;