-- Migration 046: Append-only agent_souls and agent_jobs
--
-- Converts agent_souls and agent_jobs from UPDATE-in-place to append-only
-- pattern. Adds is_archived column (primary gate) and job_key (stable
-- business identifier for jobs). Replaces full UNIQUE constraints with
-- partial unique indexes on (column) WHERE is_archived = false.
--
-- DESIGN:
--   is_archived = false  → row is alive, application cares about it
--   is_archived = true   → row is dead, historical only
--   is_active           → existing field, use as-is
--   job_key             → stable slug per job (e.g. review.inter_review)
--
-- READ PATH: WHERE is_archived = false AND is_active = true
-- WRITE PATH: save_soul_version() / save_job_version() — never UPDATE in place
--
-- Idempotent: all DDL uses IF NOT EXISTS / IF EXISTS.
-- Backfill is keyed by stable UUID from live DB.
-- Safe to run online (Pi stays running) — tables are small (2 + 44 rows).

-- ═══════════════════════════════════════════════════════════════════
-- 1. Add columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE agent_souls
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE agent_jobs
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;
ALTER TABLE agent_jobs
  ADD COLUMN IF NOT EXISTS job_key text;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Drop old full unique constraints, create partial unique indexes
--    on (column) WHERE is_archived = false.
--    CREATE INDEX CONCURRENTLY is not allowed inside a transaction
--    block, but simple_migrate runs each statement in its own
--    implicit transaction. For safety we use regular CREATE INDEX
--    since these tables are tiny (2 rows, 44 rows).
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE agent_souls DROP CONSTRAINT IF EXISTS agent_soul_id_prefix_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_souls_active_id_prefix
  ON agent_souls (id_prefix) WHERE is_archived = false;

ALTER TABLE agent_souls DROP CONSTRAINT IF EXISTS agent_soul_role_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_souls_active_role
  ON agent_souls (role) WHERE is_archived = false;

ALTER TABLE agent_jobs DROP CONSTRAINT IF EXISTS uq_agent_jobs_soul_job_priority_category;
CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_jobs_active_soul_job_key
  ON agent_jobs (soul_id, job_key) WHERE is_archived = false;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Backfill job_key for active rows that don't have one yet.
--    Keyed by stable UUID from live DB. Idempotent (WHERE job_key IS NULL).
-- ═══════════════════════════════════════════════════════════════════

-- A's active jobs (24 rows in live DB, + 1 deactivated self_monitor)
UPDATE agent_jobs SET job_key = 'review.schema_discipline'
  WHERE id = '1f10a6db-3ab6-40f0-bb44-43ee551885eb' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'review.inter_review'
  WHERE id = '465c4418-d422-4380-bbb2-4e6215e9d891' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'self_monitor.anomaly_reporting_v2'
  WHERE id = '450a12db-787d-4685-9c31-973fbdf1e990' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'self_monitor.anomaly_reporting_v1'
  WHERE id = 'd9d45795-2c85-461c-9861-9498c355ef20' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'behavior.s_behavior_review'
  WHERE id = '6efb3130-5cbb-478e-a5c0-f73b4d22a815' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'unblock.unblock_jobs'
  WHERE id = '54ccbe94-4a38-4853-8138-f227721cf8a1' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'continue.continue_work'
  WHERE id = '0e6b8cbd-6b69-40e6-aeb7-cfc73eda7378' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'safety.anti_stupidity'
  WHERE id = '6a595481-1b7d-404b-95f1-183ea7f0cd10' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'new_job.suggest_new_jobs'
  WHERE id = 'f305ee45-27d5-4337-88ad-5a59e6c3cb5d' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'unblock.unblock_tasks'
  WHERE id = '77818fb6-e1ae-42f7-a94d-974636af3560' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.stale_jobs_cleanup'
  WHERE id = '645721e5-b0ee-4217-b79c-d9d0f255b427' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'suggestion.suggest_doer_jobs'
  WHERE id = '9bc4e5cc-f215-4280-b2b7-82300dcb8f93' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.docs_match_code'
  WHERE id = 'd1202267-a33f-45fb-a926-c4f864a76e4e' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.stale_tasks_cleanup'
  WHERE id = 'f3301aa1-31fd-4842-b253-36c4a6c12d0a' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'definition.soul_review'
  WHERE id = '003c22f1-633e-4862-b20d-7f3ae4acc6eb' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'quality.split_modules'
  WHERE id = '992257ff-416b-422b-9f1e-ca61ce415b41' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'closed_loop.findings_to_issues'
  WHERE id = '3caa0390-c177-4e25-ad68-78f247178c57' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'research.competitor_research'
  WHERE id = '5f97de40-388f-48ac-88b1-4bcdfa9f3d6b' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'closed_loop.issues_have_plan'
  WHERE id = '85c12eee-4170-48fa-aece-3b5e116c2320' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'learning.read_user_files'
  WHERE id = 'afb09e32-0b41-460f-843c-07dccbb10b96' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'business.research_opportunities'
  WHERE id = '477d15a6-02e1-4686-9cf7-bb23a151fdf3' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'closed_loop.planned_to_tasks'
  WHERE id = '1653c965-dee7-44d0-985c-a7e6a66b4972' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'closed_loop.task_followup'
  WHERE id = 'fe1d1bdd-b4d8-4544-91ca-15578193b2a5' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'closed_loop.meeting_when_needed'
  WHERE id = '8a01aab2-aaed-4247-8afc-4075f9913bf6' AND job_key IS NULL;

-- S's active jobs (20 rows)
UPDATE agent_jobs SET job_key = 'behavior.address_a_findings'
  WHERE id = '43099a37-a43a-4183-874c-c922d66cd00b' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'quality.no_fake_gleam'
  WHERE id = 'd8c11c8a-f880-4b8f-822e-24ee9c7a3944' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'reminder.pick_job'
  WHERE id = 'c9ebfb2b-5816-4cea-856b-a5dc5ff6ef7b' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'review.system_review'
  WHERE id = '47ec7bb1-272b-4fcf-aeef-5ef255a2801a' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'behavior.report_issues_first'
  WHERE id = '28ddd038-527c-4f3e-848d-a60faed93764' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'unblock.execute_unblock'
  WHERE id = '2ecf80d3-2a4c-4a6e-ab11-3a05e4b22cc8' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'continue.continue_job'
  WHERE id = '9e35f92f-efe6-4ae7-baac-9fb41caa0fc2' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'continue.continue_task'
  WHERE id = 'cdcba565-c903-4e6f-9551-ba214ab8d99a' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'new_job.accept_new_jobs'
  WHERE id = 'af85b9f2-8d5c-4a64-91ae-8746670c28ab' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.close_stale_jobs'
  WHERE id = '8cc4aa9a-3f3a-469f-ac10-1f4caeb53b4d' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'new_task.accept_new_tasks'
  WHERE id = '00d73b7a-f602-46ad-b91b-3a07519d9db4' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.update_docs'
  WHERE id = '63727290-3d89-4017-85c1-8d1a9a7851c3' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'maintenance.close_stale_tasks'
  WHERE id = 'acda3be4-e2e7-45f0-a25b-2f5690c8029a' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'quality.refactor_modules'
  WHERE id = '3b583037-f55a-44d6-8c07-d0494f0b2699' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'research.execute_research'
  WHERE id = 'db138bb0-8c06-4137-9330-94461aee82ad' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'learning.save_knowledge'
  WHERE id = 'cba95ce4-e3f9-428c-81a8-4104720f9948' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'research.execute_research_tasks'
  WHERE id = '829d1a97-f1d1-466a-a2ac-919de6724d53' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'business.review_business_proposals'
  WHERE id = '2cfc75cd-7f1f-476f-b349-fcb3123c902d' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'business.implement_business_proposals'
  WHERE id = '9df468d8-ab7a-46a3-b2a0-a37f15938272' AND job_key IS NULL;
UPDATE agent_jobs SET job_key = 'definition.soul_review'
  WHERE id = '7e0cbf65-c0c6-43b4-99cc-8ec72f8689a3' AND job_key IS NULL;

-- Catch any remaining active rows that got job_key from seed or prior migration
-- (idempotent: only fills NULLs)
UPDATE agent_jobs SET job_key = 'review.schema_discipline'
  WHERE id IN (
    SELECT j.id FROM agent_jobs j
    JOIN agent_souls s ON j.soul_id = s.id
    WHERE s.id_prefix = 'A' AND j.category = 'review' AND j.job_key IS NULL
    LIMIT 1
  );
UPDATE agent_jobs SET job_key = 'self_monitor.anomaly_reporting_v1'
  WHERE id IN (
    SELECT j.id FROM agent_jobs j
    JOIN agent_souls s ON j.soul_id = s.id
    WHERE s.id_prefix = 'A' AND j.category = 'self_monitor' AND j.job_key IS NULL
    LIMIT 1
  );
UPDATE agent_jobs SET job_key = 'behavior.s_behavior_review'
  WHERE id IN (
    SELECT j.id FROM agent_jobs j
    JOIN agent_souls s ON j.soul_id = s.id
    WHERE s.id_prefix = 'A' AND j.category = 'behavior' AND j.job_key IS NULL
    LIMIT 1
  );
UPDATE agent_jobs SET job_key = 'safety.anti_stupidity'
  WHERE id IN (
    SELECT j.id FROM agent_jobs j
    JOIN agent_souls s ON j.soul_id = s.id
    WHERE s.id_prefix = 'A' AND j.category = 'safety' AND j.job_key IS NULL
    LIMIT 1
  );

-- ═══════════════════════════════════════════════════════════════════
-- 4. Deactivate the older self_monitor (d9d45795) in favour of v2
-- ═══════════════════════════════════════════════════════════════════

UPDATE agent_jobs SET is_active = false
  WHERE id = 'd9d45795-2c85-461c-9861-9498c355ef20' AND is_active = true;

-- ═══════════════════════════════════════════════════════════════════
-- 5. Lock job_key column (NOT NULL) — after backfill, no NULLs remain
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE agent_jobs ALTER COLUMN job_key SET NOT NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 6. SQL functions for append-only writes
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_soul_version(
  p_id_prefix text,
  p_content   text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- Deactivate old version
  UPDATE agent_souls
     SET is_active = false
   WHERE id_prefix = p_id_prefix
     AND is_active = true;

  -- Insert new version, copying metadata from the most recent row
  INSERT INTO agent_souls (
    id_prefix, name, role, domain, responsibility,
    trigger_type, drive_mode, activation, content,
    is_active, is_archived
  )
  SELECT
    p_id_prefix, name, role, domain, responsibility,
    trigger_type, drive_mode, activation, p_content,
    true, false
  FROM agent_souls
  WHERE id_prefix = p_id_prefix
  ORDER BY created_at DESC
  LIMIT 1
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'save_soul_version: no previous row found for id_prefix=%, cannot copy metadata', p_id_prefix;
  END IF;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

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
  -- Deactivate old version
  UPDATE agent_jobs
     SET is_active = false
   WHERE soul_id  = p_soul_id
     AND job_key  = p_job_key
     AND is_active = true;

  -- Insert new version
  INSERT INTO agent_jobs (soul_id, job, priority, category, job_key, is_active, is_archived)
  VALUES (p_soul_id, p_job, p_priority, p_category, p_job_key, true, false)
  RETURNING id INTO v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;
