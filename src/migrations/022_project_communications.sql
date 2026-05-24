CREATE TABLE IF NOT EXISTS project_communications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id TEXT NOT NULL DEFAULT '',
    from_ai TEXT NOT NULL DEFAULT '',
    message_type TEXT NOT NULL DEFAULT 'broadcast',
    content TEXT NOT NULL DEFAULT '',
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    metadata TEXT DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_project_comms_project ON project_communications(project_id);
CREATE INDEX IF NOT EXISTS idx_project_comms_from ON project_communications(from_ai);
