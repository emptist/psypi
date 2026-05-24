CREATE TABLE IF NOT EXISTS agent_prefixes (
    prefix TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT ''
);
