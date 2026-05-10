-- Migration: 080_review_learnings.sql
-- Description: Track learning patterns from inter-reviews for education

CREATE TABLE IF NOT EXISTS review_learnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Pattern info
  worker_pattern TEXT NOT NULL,        -- What worker did wrong (e.g., "forgot null check")
  category TEXT,                         -- Category (e.g., "safety", "style", "architecture")
  frequency INTEGER DEFAULT 1,           -- How many times seen
  
  -- Education
  suggested_education TEXT,              -- What worker should learn
  resource_links JSONB DEFAULT '[]',     -- Links to docs/skills
  
  -- Metadata
  first_seen TIMESTAMPTZ DEFAULT NOW(),
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT DEFAULT 'Monitor'
);

CREATE INDEX idx_review_learnings_pattern ON review_learnings(worker_pattern);
CREATE INDEX idx_review_learnings_category ON review_learnings(category);

COMMENT ON TABLE review_learnings IS 'Tracks learning patterns from inter-reviews for education system';