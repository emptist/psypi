-- Migration 006: Add model and thinking_level to agent_identities
-- These fields capture the actual AI model and reasoning mode that produced
-- an identity, replacing the ephemeral session_id as the primary differentiator.

ALTER TABLE agent_identities
    ADD COLUMN IF NOT EXISTS model VARCHAR(255) DEFAULT '',
    ADD COLUMN IF NOT EXISTS thinking_level VARCHAR(20) DEFAULT '';

-- Index for model-based lookups
CREATE INDEX IF NOT EXISTS idx_agent_identities_model ON agent_identities(model);
