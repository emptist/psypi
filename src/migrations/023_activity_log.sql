CREATE TABLE IF NOT EXISTS activity_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id TEXT NOT NULL DEFAULT '',
    activity TEXT NOT NULL DEFAULT '',
    context TEXT DEFAULT '{}',
    git_hash TEXT DEFAULT '',
    git_branch TEXT DEFAULT '',
    environment TEXT NOT NULL DEFAULT 'development',
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_log_agent ON activity_log(agent_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_timestamp ON activity_log(timestamp DESC);
