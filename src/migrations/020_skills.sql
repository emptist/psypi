CREATE TABLE IF NOT EXISTS skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    source TEXT NOT NULL DEFAULT 'local' CHECK (source IN ('clawhub', 'local', 'generated', 'imported')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'blocked', 'installed', 'uninstalled')),
    safety_score INTEGER DEFAULT 0,
    version TEXT NOT NULL DEFAULT '1.0.0',
    author TEXT,
    content TEXT,
    reference_list TEXT,
    approved_by TEXT,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_skills_status ON skills(status);
CREATE INDEX IF NOT EXISTS idx_skills_name ON skills(name);
