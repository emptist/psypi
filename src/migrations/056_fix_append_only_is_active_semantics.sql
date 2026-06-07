-- Migration 056: Fix append-only semantics — is_archived is the primary gate
--
-- Semantics:
--   is_archived = true  → historical, never read by application (primary gate)
--   is_archived = false → alive, application may read it
--   is_active = true    → enabled (business meaning, NOT touched by versioning)
--   is_active = false   → disabled (business meaning, NOT touched by versioning)
--
-- Key principle: save_soul_version / save_job_version ONLY set is_archived=true
-- on old rows. They do NOT touch is_active. If a row is later un-archived,
-- is_active retains its original business value.
--
-- This requires changing partial unique indexes from WHERE is_active = true
-- to WHERE is_active = true AND is_archived = false, because archived rows
-- may still have is_active = true (and that's correct).
--
-- Online-safe: yes (< 1 second)

-- ═══════════════════════════════════════════════════════════════════
-- 1. Fix save_soul_version — only set is_archived, do NOT touch is_active
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_soul_version(
  p_soul_id  uuid,
  p_content  text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- Only archive the old row. Do NOT change is_active — it has business meaning.
  UPDATE agent_souls SET is_archived = true WHERE id = p_soul_id AND is_archived = false;
  INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, content, is_active, is_archived)
  SELECT id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, p_content, true, false
  FROM agent_souls WHERE id = p_soul_id
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Fix save_job_version — only set is_archived, do NOT touch is_active
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_job_version(
  p_soul_id  uuid,
  p_job_key  text,
  p_job      text,
  p_priority int,
  p_category text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- Only archive the old row. Do NOT change is_active — it has business meaning.
  UPDATE agent_jobs SET is_archived = true
  WHERE soul_id = p_soul_id AND job_key = p_job_key AND is_archived = false;
  INSERT INTO agent_jobs (soul_id, job_key, job, priority, category, is_active, is_archived)
  VALUES (p_soul_id, p_job_key, p_job, p_priority, p_category, true, false)
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Fix partial unique indexes — add AND is_archived = false
-- ═══════════════════════════════════════════════════════════════════
-- Old indexes only check is_active = true, which conflicts when archived
-- rows still have is_active = true.

DROP INDEX IF EXISTS uq_agent_souls_active_id_prefix;
DROP INDEX IF EXISTS uq_agent_souls_active_role;
DROP INDEX IF EXISTS uq_agent_jobs_active_soul_job_key;

CREATE UNIQUE INDEX uq_agent_souls_active_id_prefix ON agent_souls (id_prefix) WHERE is_active = true AND is_archived = false;
CREATE UNIQUE INDEX uq_agent_souls_active_role ON agent_souls (role) WHERE is_active = true AND is_archived = false;
CREATE UNIQUE INDEX uq_agent_jobs_active_soul_job_key ON agent_jobs (soul_id, job_key) WHERE is_active = true AND is_archived = false;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Restore is_active on archived rows that were incorrectly set to false
-- ═══════════════════════════════════════════════════════════════════
-- Migrations 052-055 incorrectly set is_active = false on archived rows.
-- We don't know the original is_active value, but since these rows were
-- the active version before being superseded, they were likely is_active = true.
-- Restore them to is_active = true — is_archived = true already prevents
-- them from being read.

UPDATE agent_souls SET is_active = true WHERE is_archived = true AND is_active = false;
UPDATE agent_jobs SET is_active = true WHERE is_archived = true AND is_active = false;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

-- Check: no archived rows with is_active = false (all restored)
SELECT 'archived_with_is_active_false' as check_name, COUNT(*) as count
FROM (
  SELECT 1 FROM agent_souls WHERE is_archived = true AND is_active = false
  UNION ALL
  SELECT 1 FROM agent_jobs WHERE is_archived = true AND is_active = false
) sub;

-- Check: unique index works (at most one active non-archived per key)
SELECT 'active_non_archived_souls' as check_name, id_prefix, COUNT(*) as count
FROM agent_souls WHERE is_active = true AND is_archived = false
GROUP BY id_prefix;
