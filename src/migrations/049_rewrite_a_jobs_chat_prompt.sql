-- Migration 049: Rewrite A-bot jobs in chat-prompt style
--
-- S-bot manually edited agent_jobs via psql, breaking the append-only
-- pattern. This migration:
--   1. Deactivates the duplicate safety.anti_stupidity_behavior job
--   2. Deactivates closed_loop.meeting_when_needed (A can't convene meetings)
--   3. Rewrites all A-bot jobs in chat-prompt directive style
--
-- All changes use save_job_version() to preserve history.
--
-- DESIGN:
--   A-bot jobs should be chat-prompt directives, not formal specs.
--   Style: "Ask S to...", "Check if S...", "Remind S that..."
--   A reads these and naturally formulates what to say to S.
--
-- ONLINE-SAFE NOTES:
--   Table size: ~50 rows in agent_jobs
--   Lock duration: < 1 second
--   Pi can stay running: yes

-- ═══════════════════════════════════════════════════════════════════
-- 1. Deactivate duplicate safety.anti_stupidity_behavior
-- ═══════════════════════════════════════════════════════════════════

UPDATE agent_jobs 
SET is_active = false, is_archived = true
WHERE id = 'aab71ceb-05fb-4cfa-be05-a2f0f8f57995'
  AND job_key = 'safety.anti_stupidity_behavior'
  AND is_active = true;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Deactivate closed_loop.meeting_when_needed for A
--    (A and S communicate through psypi, not through meetings)
-- ═══════════════════════════════════════════════════════════════════

UPDATE agent_jobs 
SET is_active = false, is_archived = true
WHERE id = '8a01aab2-aaed-4247-8afc-4075f9913bf6'
  AND job_key = 'closed_loop.meeting_when_needed'
  AND soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1)
  AND is_active = true;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Rewrite A-bot jobs in chat-prompt style
--    Uses save_job_version() to preserve history (append-only)
-- ═══════════════════════════════════════════════════════════════════

-- Get A's soul_id
DO $$
DECLARE
  v_a_soul_id uuid;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  -- Review jobs
  PERFORM save_job_version(v_a_soul_id, 'review.schema_discipline',
    'Ask S to show what they changed. Check for fake IDs, fake UUIDs, or any ID format in their response. If you see one, remind them the hook owns ID assignment.',
    1, 'review');

  PERFORM save_job_version(v_a_soul_id, 'review.inter_review',
    'Ask S what they just worked on. Check if they planned before doing. Look for anything that seems off — wrong types, missing decoders, fake Gleam, bypassing psypi-commit.',
    1, 'review');

  -- Self-monitor
  PERFORM save_job_version(v_a_soul_id, 'self_monitor.anomaly_reporting_v2',
    'If something feels wrong with your environment, tell S to investigate. Be specific: what you tried, what you expected, what you got. Do not wait for the human.',
    1, 'self_monitor');

  -- Behavior
  PERFORM save_job_version(v_a_soul_id, 'behavior.s_behavior_review',
    'Check if S reported issues before fixing. Did they plan before acting? Did they update docs after changes? Remind them if they skipped steps.',
    2, 'behavior');

  -- Unblock
  PERFORM save_job_version(v_a_soul_id, 'unblock.unblock_jobs',
    'When S seems stuck, ask them to check conversation history, DB state, and file contents. Direct them with specific questions about what is missing.',
    2, 'unblock');

  PERFORM save_job_version(v_a_soul_id, 'unblock.unblock_tasks',
    'When S is stuck on a task, ask them what is blocking them. Direct them to check conversation history and DB state.',
    4, 'unblock');

  -- Continue
  PERFORM save_job_version(v_a_soul_id, 'continue.continue_work',
    'Help S figure out what to do next. Ask them what they were working on and what the next logical step is.',
    3, 'continue');

  -- Safety
  PERFORM save_job_version(v_a_soul_id, 'safety.anti_stupidity',
    'Watch for dangerous behavior. Remind S: do not delete without committing first, do not use sqlite3, do not restart Pi, do not create fake Gleam files.',
    3, 'safety');

  -- New job
  PERFORM save_job_version(v_a_soul_id, 'new_job.suggest_new_jobs',
    'When S has no in-progress work, suggest they pick a job from their list. Do not suggest until they are idle.',
    4, 'new_job');

  -- Maintenance
  PERFORM save_job_version(v_a_soul_id, 'maintenance.stale_jobs_cleanup',
    'Ask S to list stale jobs. Remind them to clean up or reprioritize jobs older than 7 days.',
    5, 'maintenance');

  PERFORM save_job_version(v_a_soul_id, 'maintenance.docs_match_code',
    'Check if docs match code. Remind S to update docs after changes.',
    6, 'maintenance');

  PERFORM save_job_version(v_a_soul_id, 'maintenance.stale_tasks_cleanup',
    'Ask S to list stale tasks. Remind them to close or reprioritize tasks older than 7 days.',
    6, 'maintenance');

  -- Suggestion
  PERFORM save_job_version(v_a_soul_id, 'suggestion.suggest_doer_jobs',
    'When context is right, suggest S do research, business proposals, or learning. You decide whether to suggest, S decides how to execute.',
    5, 'suggestion');

  -- Definition
  PERFORM save_job_version(v_a_soul_id, 'definition.soul_review',
    'Ask S if their soul and jobs still match reality. Suggest updates if stale or wrong.',
    7, 'definition');

  -- Quality
  PERFORM save_job_version(v_a_soul_id, 'quality.split_modules',
    'Check if any modules are too large. Suggest splitting when they exceed 100 lines.',
    7, 'quality');

  -- Closed loop (simplified — A asks S about previous feedback)
  PERFORM save_job_version(v_a_soul_id, 'closed_loop.findings_to_issues',
    'Ask S what they did with your last feedback. If they have not created issues for significant findings, remind them.',
    8, 'closed_loop');

  PERFORM save_job_version(v_a_soul_id, 'closed_loop.issues_have_plan',
    'Ask S if the issues they created have plans. If not, remind them to discuss and plan before acting.',
    9, 'closed_loop');

  PERFORM save_job_version(v_a_soul_id, 'closed_loop.planned_to_tasks',
    'Ask S if the plans they made have become tasks. If not, remind them to create tasks when plans are sound.',
    10, 'closed_loop');

  PERFORM save_job_version(v_a_soul_id, 'closed_loop.task_followup',
    'Ask S if they addressed your previous findings. If not, remind them to follow up on unaddressed items.',
    11, 'closed_loop');

  -- Research
  PERFORM save_job_version(v_a_soul_id, 'research.competitor_research',
    'Ask S to research competitors like openclaw and lobehub. Remind them to document findings.',
    8, 'research');

  -- Learning
  PERFORM save_job_version(v_a_soul_id, 'learning.read_user_files',
    'Ask S to read user files. Remind them to save knowledge to memory.',
    9, 'learning');

  -- Business
  PERFORM save_job_version(v_a_soul_id, 'business.research_opportunities',
    'Ask S to research business opportunities and draft proposals.',
    10, 'business');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Verification
-- ═══════════════════════════════════════════════════════════════════

-- Verify: no duplicate active job_keys per soul
SELECT soul_id, job_key, COUNT(*) as active_count
FROM agent_jobs WHERE is_active = true
GROUP BY soul_id, job_key HAVING COUNT(*) > 1;

-- Verify: meeting_when_needed is deactivated for A
SELECT id, job_key, is_active, is_archived
FROM agent_jobs 
WHERE job_key = 'closed_loop.meeting_when_needed'
  AND soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1);

-- Verify: A has ~22 active jobs (23 minus deactivated meeting)
SELECT COUNT(*) as a_active_jobs
FROM agent_jobs j
JOIN agent_souls s ON j.soul_id = s.id
WHERE s.id_prefix = 'A' AND j.is_active = true AND j.is_archived = false;
