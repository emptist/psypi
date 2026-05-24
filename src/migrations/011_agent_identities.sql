CREATE TABLE IF NOT EXISTS agent_identities (
    id TEXT PRIMARY KEY,
    project TEXT NOT NULL DEFAULT '',
    git_hash TEXT NOT NULL DEFAULT '',
    machine_fingerprint TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',
    session_id TEXT NOT NULL DEFAULT '',
    model VARCHAR(255) DEFAULT '',
    thinking_level VARCHAR(20) DEFAULT '',
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_identities_model ON agent_identities(model);
CREATE INDEX IF NOT EXISTS idx_agent_identities_created ON agent_identities(created_at DESC);
