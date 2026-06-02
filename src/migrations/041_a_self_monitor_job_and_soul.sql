-- Migration 041: Add A's self-monitor job + soul workflow.
--
-- Why this change
--   The user clarified on 2026-06-02:
--   "it's better if we add info in A-bot's Soul and jobs, and suggest him
--    give S-bot feedback when he find he can't use some tool or the env
--    feels strange, so that S-bot can investigate, so human is not needed
--    in the process, at all."
--
--   The /autonomic-listen tool is debug-only. Normal operation must work
--   without any human in the loop. When A detects something is wrong with
--   its environment (tool error, missing data, weird state), A's job is to
--   report the anomaly to S via pi.sendMessage so S can investigate and
--   fix it. A does NOT wait for the human.
--
-- What this migration does
--   1. Adds a high-priority "self-monitor" job to A's agent_jobs.
--   2. Adds a "## Self-Monitor Workflow" section to A's soul so A knows
--      exactly how to behave when something is off.

-- 1. Add the self-monitor job. Idempotent via ON CONFLICT on (soul_id, job).
INSERT INTO agent_jobs (id, soul_id, job, priority, category, is_active)
SELECT
  gen_random_uuid(),
  aus.id,
  'Self-monitor: when call_monitor() returns no data, when inter_review.save() fails, when ctx state looks weird (no entries, no cwd, missing callbacks), or when you find you cannot do something you expected to do — report the anomaly to S via pi.sendMessage(..., triggerTurn: true) so S can investigate. Be specific: what you tried, what you expected, what you got. Do NOT wait for the human. S is the fix-it agent. The human is not in the loop. The /autonomic-listen tool is debug-only.',
  1,
  'self_monitor',
  true
FROM agent_souls aus
WHERE aus.id_prefix = 'A' AND aus.is_active = true
ON CONFLICT DO NOTHING;

-- 2. Add the Self-Monitor Workflow section to A's soul. Idempotent:
--    only inserts if the section heading isn't already there.
UPDATE agent_souls
SET content = content || E'\n\n## Self-Monitor Workflow (no human in the loop)\nWhen I detect something is wrong with my environment, I report it to S — I do NOT wait for the human. Specifically:\n- call_monitor() returned no text or an error -> pi.sendMessage to S with what I sent and what came back.\n- inter_review.save() failed -> pi.sendMessage to S with the error string.\n- ctx state looks weird (empty entries, no cwd, unexpected payload shape) -> pi.sendMessage to S with the unexpected value.\n- I find I cannot do something I expected to do (a Gleam function missing, an FFI returns a wrong shape, my prompt is empty, my soul is missing fields) -> pi.sendMessage to S with the symptom.\n\nS is the fix-it agent. S has all psypi-* tools. S will query, diagnose, and fix. I write a clear report (what I tried, what I expected, what I got) and let S take over. The /autonomic-listen tool is a debug fallback only; it is not part of normal operation. psypi is designed to let the human do less and less until no human is actually needed.\n'
WHERE id_prefix = 'A' AND is_active = true
  AND position(E'## Self-Monitor Workflow' IN content) = 0;

-- Safety check.
DO $$
DECLARE
  job_count INT;
  soul_text TEXT;
BEGIN
  SELECT COUNT(*) INTO job_count
  FROM agent_jobs aj
  JOIN agent_souls aus ON aj.soul_id = aus.id
  WHERE aus.id_prefix = 'A'
    AND aus.is_active = true
    AND aj.category = 'self_monitor'
    AND aj.is_active = true;

  IF job_count < 1 THEN
    RAISE EXCEPTION 'Migration 041: self-monitor job not present for A soul.';
  END IF;

  SELECT content INTO soul_text
  FROM agent_souls
  WHERE id_prefix = 'A' AND is_active = true
  LIMIT 1;

  IF position(E'Self-Monitor Workflow' IN soul_text) = 0 THEN
    RAISE EXCEPTION 'Migration 041: Self-Monitor Workflow section missing from A soul.';
  END IF;

  RAISE NOTICE 'Migration 041: A soul has % self-monitor job(s) and the workflow section.', job_count;
END $$;
