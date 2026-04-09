-- migrate:up
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    ran_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);
-- migrate:down
DROP TABLE IF EXISTS schema_migrations;