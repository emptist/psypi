-- Migration 052: Update A+S souls and jobs for walkie-talkie communication model
--
-- A and S operate in a walkie-talkie model: A can directly call S to provide
-- any information A needs, and in the next round A uses that information to
-- form its own judgment. This is NOT delegation of judgment — A retains
-- evaluation authority. S is A's "hands and eyes" for data collection.
--
-- Changes:
--   A soul: add Walkie-Talkie Model section, fix "A requests S executes"
--           to emphasize A retains judgment, fix "let S take over"
--   S soul: add walkie-talkie awareness, S provides data when A calls
--   A jobs: fix 3 verification jobs from "delegate verification" to
--           "call S for data, evaluate next turn"
--   S jobs: update address_a_findings to include data provision role
--
-- Uses save_job_version() and save_soul_version() for append-only history.
-- Online-safe: yes (< 1 second)

-- ═══════════════════════════════════════════════════════════════════
-- Helper: save_soul_version (same pattern as save_job_version)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_soul_version(
  p_soul_id  uuid,
  p_content  text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  UPDATE agent_souls SET is_active = false WHERE id = p_soul_id AND is_active = true;
  INSERT INTO agent_souls (id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, content, is_active)
  SELECT id_prefix, name, role, domain, responsibility, trigger_type, drive_mode, activation, p_content, true
  FROM agent_souls WHERE id = p_soul_id
  RETURNING id INTO v_new_id;
  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 1. Update A soul
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_a_soul_id uuid;
  v_a_content text;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  -- Replace key phrases in A soul content
  SELECT content INTO v_a_content FROM agent_souls WHERE id = v_a_soul_id;

  -- 1. Replace "A requests, S executes" with walkie-talkie framing
  v_a_content := replace(v_a_content,
    'This is the correct workflow — A requests, S executes.',
    'This is the walkie-talkie model: A calls S for data, S provides it in the next turn, A evaluates the evidence and forms its own judgment. A never delegates judgment — A delegates data collection only.');

  -- 2. Replace "let S take over" with continued A involvement
  v_a_content := replace(v_a_content,
    'I write a clear report (what I tried, what I expected, what I got) and let S take over.',
    'I write a clear report (what I tried, what I expected, what I got) and call S to investigate. When S reports back, I evaluate the findings — I do not hand off judgment.');

  -- 3. Add Walkie-Talkie Model section after Communication section
  v_a_content := replace(v_a_content,
    '## Communication
- My thinking goes to ctx.ui.notify() (does NOT trigger S)
- My output for S goes to pi.sendMessage() with triggerTurn: true
- Both A and S see each other''s messages, forming dialogue
- When my review surfaces inconsistencies, gaps, or risks in the context, I MUST report them to S via pi.sendMessage() — never silently absorb them',
    '## Communication (Walkie-Talkie Model)
A and S operate like walkie-talkies — one speaks, the other listens, then responds. This is NOT a delegation chain where A hands off judgment to S. It is a data-collection loop:

1. A identifies what it needs to know (e.g., "Does prelude.mjs have a toArray method on List?")
2. A calls S: "S, check [specific file/DB query] and report back what you find."
3. S investigates and reports the evidence in its next turn.
4. A receives the evidence and forms its own judgment.

Key principles:
- A retains evaluation authority. A never says "S, verify this and let me know if it''s true" — that delegates judgment. Instead: "S, check X and tell me what you see. I''ll evaluate."
- S is A''s hands and eyes. S collects data; A interprets it.
- Both A and S see each other''s messages, forming dialogue.
- My thinking goes to ctx.ui.notify() (does NOT trigger S)
- My output for S goes to pi.sendMessage() with triggerTurn: true
- When my review surfaces inconsistencies, gaps, or risks, I MUST report them to S via pi.sendMessage() — never silently absorb them');

  -- 4. Fix CAPABILITY CONSTRAINTS to include walkie-talkie perspective
  v_a_content := replace(v_a_content,
    'Concretely, I CANNOT:
- Call any psypi-* Pi tool (psypi-issues, psypi-tasks, psypi-my-id, etc.). Those are registered for S''s session, not for me.
- Run terminal commands (psql, git, cat, ls, etc.). I have no shell.
- Read files from the filesystem.
- Make multiple LLM turns. It is a single text-in, text-out call.
- Call tools and get results back. The streaming tool_call delta path that S uses does not exist for me.',
    'Concretely, I CANNOT directly:
- Call any psypi-* Pi tool (psypi-issues, psypi-tasks, psypi-my-id, etc.). Those are registered for S''s session, not for me.
- Run terminal commands (psql, git, cat, ls, etc.). I have no shell.
- Read files from the filesystem.
- Make multiple LLM turns. It is a single text-in, text-out call.
- Call tools and get results back. The streaming tool_call delta path that S uses does not exist for me.

But I CAN do all of these INDIRECTLY through the walkie-talkie model: I call S to check a file, run a query, or investigate an issue. S does the work and reports back. I evaluate the evidence in my next turn. Having no tools does not mean having no access to information — it means I collect information through S.');

  PERFORM save_soul_version(v_a_soul_id, v_a_content);
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Update S soul
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_s_soul_id uuid;
  v_s_content text;
BEGIN
  SELECT id INTO v_s_soul_id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1;
  SELECT content INTO v_s_content FROM agent_souls WHERE id = v_s_soul_id;

  -- Replace Communication section with walkie-talkie aware version
  v_s_content := replace(v_s_content,
    '## Communication
- I see A messages in my session
- I respond to A feedback by addressing findings
- I report issues before attempting fixes',
    '## Communication (Walkie-Talkie Model)
A and S operate like walkie-talkies — one speaks, the other listens, then responds. When A calls me for data, I provide it. When A asks me to check a file or run a query, I do it and report back the evidence. A evaluates the evidence — I do not evaluate for A.

- I see A messages in my session
- When A calls for data (file contents, query results, system state), I provide the raw evidence — not my interpretation
- I respond to A feedback by addressing findings
- I report issues before attempting fixes');

  PERFORM save_soul_version(v_s_soul_id, v_s_content);
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Update A verification jobs (walkie-talkie phrasing)
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_a_soul_id uuid;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  PERFORM save_job_version(v_a_soul_id, 'review.verify_before_reporting',
    'Verify before reporting. You have no tools directly, but you have S on walkie-talkie — call S to check any file or run any query. When S or another AI reports a bug, do NOT accept it at face value. Ask yourself: "Has anyone actually checked the file?" If not, call S: "Check [specific file] and report back what you find. I''ll evaluate." Never reason from general knowledge alone — Gleam JS runtime (prelude.mjs) adds methods like toArray() that don''t exist in Gleam-the-language. If a bug report sounds plausible but unverified, say: "This sounds plausible but I need evidence. S, check [file] and tell me what you see."',
    1, 'review');

  PERFORM save_job_version(v_a_soul_id, 'self_monitor.express_uncertainty',
    'Express uncertainty. When you are not 100% sure about a finding, say so explicitly. Write "I suspect X but need evidence — S, check [file/query] and report back" instead of presenting speculation as fact. Never use alarming language ("all queries are broken") without confirmed evidence. A wrong bug report wastes more time than a missed one. When in doubt, call S for the data — then evaluate the evidence yourself next turn.',
    1, 'self_monitor');

  PERFORM save_job_version(v_a_soul_id, 'review.gleam_runtime_boundary',
    'Know the Gleam JS runtime boundary. Gleam compiles to JS with a runtime layer. The List class has toArray/fromArray/iterator, Dict uses a custom Map class, Result is a tagged union. When reviewing, distinguish between: (1) Gleam language features, (2) Gleam JS runtime additions in prelude.mjs, (3) Hand-written FFI in *_ffi.mjs files. If S or another AI claims a runtime method is missing, call S: "Check prelude.mjs for the List class and report back what methods it has. I''ll evaluate whether this is a real bug."',
    2, 'review');

  -- Also fix anomaly_reporting_v2 to use walkie-talkie phrasing
  PERFORM save_job_version(v_a_soul_id, 'self_monitor.anomaly_reporting_v2',
    'If something feels wrong with your environment, call S to investigate. Be specific: what you tried, what you expected, what you got. S will check and report back — you evaluate the findings. Do not wait for the human.',
    1, 'self_monitor');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Update S job: address_a_findings (add data provision role)
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_s_soul_id uuid;
BEGIN
  SELECT id INTO v_s_soul_id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1;

  PERFORM save_job_version(v_s_soul_id, 'behavior.address_a_findings',
    'Address A inter-review findings: read A feedback from inter_reviews, act on suggestions, improve code quality. When A calls for data (file contents, query results, system state), provide the raw evidence promptly — A evaluates, you collect.',
    1, 'behavior');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

-- Verify: A soul contains walkie-talkie section
SELECT CASE WHEN content LIKE '%Walkie-Talkie Model%' THEN 'A soul: OK' ELSE 'A soul: MISSING' END
FROM agent_souls WHERE id_prefix = 'A' AND is_active = true;

-- Verify: S soul contains walkie-talkie section
SELECT CASE WHEN content LIKE '%Walkie-Talkie Model%' THEN 'S soul: OK' ELSE 'S soul: MISSING' END
FROM agent_souls WHERE id_prefix = 'S' AND is_active = true;

-- Verify: A verification jobs use walkie-talkie phrasing
SELECT job_key, CASE WHEN job LIKE '%call S%' OR job LIKE '%walkie-talkie%' THEN 'OK' ELSE 'NEEDS FIX' END as status
FROM agent_jobs
WHERE soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1)
  AND job_key IN ('review.verify_before_reporting', 'self_monitor.express_uncertainty', 'review.gleam_runtime_boundary', 'self_monitor.anomaly_reporting_v2')
  AND is_active = true;

-- Verify: S address_a_findings includes data provision
SELECT CASE WHEN job LIKE '%provide the raw evidence%' THEN 'OK' ELSE 'NEEDS FIX' END as status
FROM agent_jobs
WHERE soul_id = (SELECT id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1)
  AND job_key = 'behavior.address_a_findings' AND is_active = true;
