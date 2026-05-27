-- Migration 027: Add review_findings table and improve system_reviews
--
-- The system_reviews table exists but stores findings as a flat jsonb array,
-- making it impossible to query, filter, or update individual findings.
-- This migration adds:
--   1. review_findings table — one row per finding (replaces jsonb blob)
--   2. project_id column on system_reviews — for multi-project isolation
--   3. 'system' to review_type CHECK constraint
--   4. review_findings_id_seq for stable finding numbering

-- Step 1: Add project_id to system_reviews
ALTER TABLE system_reviews
  ADD COLUMN IF NOT EXISTS project_id uuid;

-- Step 2: Add 'system' to review_type constraint
ALTER TABLE system_reviews DROP CONSTRAINT reviews_review_type_check;
ALTER TABLE system_reviews ADD CONSTRAINT reviews_review_type_check
  CHECK (review_type = ANY (ARRAY['code', 'design', 'qc', 'peer', 'task', 'security', 'system', 'other']));

-- Step 3: Create review_findings table
CREATE TABLE IF NOT EXISTS review_findings (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  review_id uuid NOT NULL REFERENCES system_reviews(id) ON DELETE CASCADE,
  finding_number int NOT NULL,
  severity text NOT NULL CHECK (severity = ANY (ARRAY['critical', 'high', 'medium', 'low', 'cosmetic'])),
  category text NOT NULL,
  module text,
  title text NOT NULL,
  description text NOT NULL,
  evidence text,
  impact text,
  status text NOT NULL DEFAULT 'open' CHECK (status = ANY (ARRAY['open', 'confirmed', 'disputed', 'fixed', 'wont_fix', 'duplicate', 'retracted'])),
  related_issue_id uuid REFERENCES issues(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  UNIQUE(review_id, finding_number)
);

-- Step 4: Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_findings_review ON review_findings(review_id);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON review_findings(severity);
CREATE INDEX IF NOT EXISTS idx_findings_status ON review_findings(status);
CREATE INDEX IF NOT EXISTS idx_findings_category ON review_findings(category);
CREATE INDEX IF NOT EXISTS idx_findings_module ON review_findings(module);
CREATE INDEX IF NOT EXISTS idx_findings_issue ON review_findings(related_issue_id);
CREATE INDEX IF NOT EXISTS idx_system_reviews_project ON system_reviews(project_id);

-- Step 5: Update trigger for review_findings
CREATE OR REPLACE FUNCTION update_finding_timestamp()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_review_findings_timestamp ON review_findings;
CREATE TRIGGER update_review_findings_timestamp
  BEFORE UPDATE ON review_findings
  FOR EACH ROW EXECUTE FUNCTION update_finding_timestamp();
