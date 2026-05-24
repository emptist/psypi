CREATE TABLE IF NOT EXISTS issues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('critical', 'high', 'medium', 'low')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    issue_type TEXT NOT NULL DEFAULT 'bug' CHECK (issue_type IN ('bug', 'feature', 'improvement', 'security', 'performance', 'question')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    created_by TEXT NOT NULL DEFAULT '',
    discovered_by TEXT,
    environment TEXT,
    git_branch TEXT,
    git_hash TEXT,
    reported_by TEXT,
    source TEXT,
    project_id TEXT
);

CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);
CREATE INDEX IF NOT EXISTS idx_issues_severity ON issues(severity);
CREATE INDEX IF NOT EXISTS idx_issues_created ON issues(created_at DESC);
