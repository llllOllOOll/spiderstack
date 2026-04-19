-- migrate:up

CREATE TABLE IF NOT EXISTS todos (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert sample todos
INSERT INTO todos (title, completed) VALUES
('Aprender Zig', true),
('Criar aplicação Spider', false),
('Implementar HTMX', false);

-- migrate:down
DROP TABLE IF EXISTS todos;