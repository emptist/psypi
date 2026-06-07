-- Migration 051: Fix verification jobs to match A-bot's actual capabilities
--
-- A-bot has NO tools — it cannot read files, query the database, or run
-- commands. The previous job text said "read the actual file" and "check
-- prelude.mjs", which A literally cannot do. This migration rewrites the
-- three verification jobs to instruct A to:
--   1. Flag unverified claims explicitly
--   2. Ask S to verify when A cannot
--   3. Never accept a bug report at face value without verification
--
-- Uses save_job_version() to preserve history (append-only).
-- Online-safe: yes (3 updates, < 1 second)

DO $$
DECLARE
  v_a_soul_id uuid;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  PERFORM save_job_version(v_a_soul_id, 'review.verify_before_reporting',
    'Verify before reporting. You have NO tools — you cannot read files or query the DB. When S or another AI reports a bug, do NOT accept it at face value. Ask yourself: "Has anyone actually checked the file?" If not, tell S: "I cannot verify this claim. Please check [specific file] before we proceed." Never reason from general knowledge alone — Gleam JS runtime (prelude.mjs) adds methods like toArray() that don''t exist in Gleam-the-language. If a bug report sounds plausible but unverified, say so: "This sounds plausible but I have not seen the evidence. S, please verify."',
    1, 'review');

  PERFORM save_job_version(v_a_soul_id, 'self_monitor.express_uncertainty',
    'Express uncertainty. You have NO tools — you cannot verify anything yourself. When you are not 100% sure about a finding, say so explicitly. Write "I suspect X but cannot verify — S please confirm" instead of presenting speculation as fact. Never use alarming language ("all queries are broken") without confirmed evidence. A wrong bug report wastes more time than a missed one. When in doubt, ask S to check.',
    1, 'self_monitor');

  PERFORM save_job_version(v_a_soul_id, 'review.gleam_runtime_boundary',
    'Know the Gleam JS runtime boundary. You have NO tools — you cannot check files yourself. But you must know that Gleam compiles to JS with a runtime layer. The List class has toArray/fromArray/iterator, Dict uses a custom Map class, Result is a tagged union. When reviewing, distinguish between: (1) Gleam language features, (2) Gleam JS runtime additions in prelude.mjs, (3) Hand-written FFI in *_ffi.mjs files. If S or another AI claims a runtime method is missing, tell S: "Please check prelude.mjs before we treat this as a bug — the JS runtime adds methods that Gleam-the-language does not have."',
    2, 'review');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

SELECT job_key, LEFT(job, 80) as preview
FROM agent_jobs
WHERE soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1)
  AND job_key IN ('review.verify_before_reporting', 'self_monitor.express_uncertainty', 'review.gleam_runtime_boundary')
  AND is_active = true;
