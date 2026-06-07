-- Migration 050: Add verification-oriented jobs for A-bot
--
-- After an AI agent reported a false bug (claiming listToArray() was broken
-- because "Gleam List has no toArray method" — it does, in prelude.mjs),
-- we add three high-priority jobs to instill verification discipline.
--
-- These jobs embed "mini-skills" directly in the job text:
--   1. verify_before_reporting — always read the file before concluding
--   2. express_uncertainty — say "I suspect" not "it's broken"
--   3. gleam_runtime_boundary — know where Gleam-the-language ends
--      and Gleam-JS-runtime begins
--
-- Uses save_job_version() to preserve history (append-only).
--
-- Online-safe: yes (3 inserts, < 1 second)

DO $$
DECLARE
  v_a_soul_id uuid;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  -- Priority 1: Verify before reporting
  -- Triggered by: another AI claiming listToArray() was broken without
  -- checking prelude.mjs. The method exists on the List base class.
  PERFORM save_job_version(v_a_soul_id, 'review.verify_before_reporting',
    'Verify before reporting. When you find a potential bug, read the actual file before concluding. Never reason from general knowledge alone — Gleam JS runtime (prelude.mjs) adds methods like toArray() that don''t exist in Gleam-the-language. Check build/dev/javascript/prelude.mjs for List, Result, Dict methods before claiming something is missing.',
    1, 'review');

  -- Priority 1: Express uncertainty
  -- Triggered by: an AI writing "all queries are broken" without evidence.
  -- A wrong bug report is worse than no bug report.
  PERFORM save_job_version(v_a_soul_id, 'self_monitor.express_uncertainty',
    'Express uncertainty. When you are not 100% sure about a finding, say so explicitly. Write "I suspect X but have not verified" instead of presenting speculation as fact. Never use alarming language ("all queries are broken") without confirmed evidence. A wrong bug report wastes more time than a missed one.',
    1, 'self_monitor');

  -- Priority 2: Know the Gleam JS runtime boundary
  -- Triggered by: confusion between Gleam language features and JS runtime
  -- additions. The List class has toArray/fromArray/iterator, Dict uses a
  -- custom Map class, Result is a tagged union.
  PERFORM save_job_version(v_a_soul_id, 'review.gleam_runtime_boundary',
    'Know the Gleam JS runtime boundary. Gleam compiles to JS with a runtime layer. The List class has toArray/fromArray/iterator, Dict uses a custom Map class, Result is a tagged union. When reviewing FFI code, distinguish between: (1) Gleam language features, (2) Gleam JS runtime additions in prelude.mjs, (3) Hand-written FFI in *_ffi.mjs files. Misunderstanding this boundary leads to false bug reports.',
    2, 'review');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

-- Verify: 3 new jobs exist for A
SELECT job_key, priority, category, LEFT(job, 50) as preview
FROM agent_jobs
WHERE soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1)
  AND job_key IN ('review.verify_before_reporting', 'self_monitor.express_uncertainty', 'review.gleam_runtime_boundary')
  AND is_active = true;

-- Verify: A now has 25 active jobs (22 + 3)
SELECT COUNT(*) as a_active_jobs
FROM agent_jobs j
JOIN agent_souls s ON j.soul_id = s.id
WHERE s.id_prefix = 'A' AND j.is_active = true AND j.is_archived = false;
