-- Migration 005: System Directives table
-- Atonomic Worker writes directives here → before_agent_start reads → injects into system prompt

CREATE TABLE IF NOT EXISTS system_directives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id TEXT NOT NULL DEFAULT 'psypi',
    directive_text TEXT NOT NULL,
    priority TEXT DEFAULT 'medium' CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    is_active BOOLEAN DEFAULT true,
    source TEXT DEFAULT 'autonomic',  -- who created it: autonomic, human, system
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '1 hour',
    consumed_at TIMESTAMPTZ,
    -- Prevent duplicate directives
    UNIQUE(agent_id, directive_text, is_active)
);

CREATE INDEX IF NOT EXISTS idx_system_directives_agent_active 
    ON system_directives(agent_id, is_active) 
    WHERE is_active = true;

-- Seed: initial self-describing directive
INSERT INTO system_directives (agent_id, directive_text, priority, source, expires_at)
VALUES (
    'psypi',
    'System directives are active. Check system_directives table for pending directives before starting work.',
    'low',
    'system',
    NOW() + INTERVAL '24 hours'
)
ON CONFLICT DO NOTHING;
