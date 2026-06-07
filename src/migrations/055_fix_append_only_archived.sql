-- Migration 055: Fix save_soul_version to set is_archived=true on old rows
--
-- The append-only pattern requires that when a new version is created,
-- the old row should be marked is_archived=true (not just is_active=false).
-- is_archived=true means "this row has been superseded by a newer version".
--
-- Also fixes existing un-archived old rows from migrations 052-054.
-- Online-safe: yes (< 1 second)

-- ═══════════════════════════════════════════════════════════════════
-- 1. Fix save_soul_version function
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_soul_version(
  p_soul_id  uuid,
  p_content  text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  UPDATE agent_souls SET is_active = false, is_archived = true WHERE id = p_soul_id AND is_active = true;
  INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, content, is_active)
  SELECT id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, p_content, true
  FROM agent_souls WHERE id = p_soul_id
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Fix save_job_version function (same pattern)
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
  UPDATE agent_jobs SET is_active = false, is_archived = true
  WHERE soul_id = p_soul_id AND job_key = p_job_key AND is_active = true;
  INSERT INTO agent_jobs (soul_id, job_key, job, priority, category, is_active)
  VALUES (p_soul_id, p_job_key, p_job, p_priority, p_category, true)
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Fix existing old rows: mark is_archived=true where is_active=false
-- ═══════════════════════════════════════════════════════════════════

UPDATE agent_souls SET is_archived = true WHERE is_active = false AND is_archived = false;
UPDATE agent_jobs SET is_archived = true WHERE is_active = false AND is_archived = false;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

SELECT 'souls' as table_name,
  SUM(CASE WHEN is_active = false AND is_archived = false THEN 1 ELSE 0 END) as unarchived_inactive,
  SUM(CASE WHEN is_active = true THEN 1 ELSE 0 END) as active
FROM agent_souls
UNION ALL
SELECT 'jobs',
  SUM(CASE WHEN is_active = false AND is_archived = false THEN 1 ELSE 0 END),
  SUM(CASE WHEN is_active = true THEN 1 ELSE 0 END)
FROM agent_jobs;
