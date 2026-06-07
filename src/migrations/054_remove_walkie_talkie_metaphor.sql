-- Migration 054: Remove "walkie-talkie" metaphor from souls and jobs
--
-- "Walkie-talkie" was a metaphor for understanding the A-S dialogue pattern.
-- It should not appear in production text. Replace with natural language
-- describing the turn-based dialogue model.
--
-- Uses save_soul_version() and save_job_version() for append-only history.
-- Online-safe: yes (< 1 second)

-- ═══════════════════════════════════════════════════════════════════
-- 1. Fix A soul content
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_a_soul_id uuid;
  v_a_content text;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;
  SELECT content INTO v_a_content FROM agent_souls WHERE id = v_a_soul_id;

  -- Replace "Walkie-Talkie Model" section header and framing
  v_a_content := replace(v_a_content,
    '## Communication (Walkie-Talkie Model)
A and S operate like walkie-talkies — one speaks, the other listens, then responds. This is NOT a delegation chain where A hands off judgment to S. It is a data-collection loop:',
    '## Communication (Turn-Based Dialogue)
A and S take turns — one speaks, the other responds. This is NOT a delegation chain where A hands off judgment to S. It is a data-collection loop:');

  -- Replace "walkie-talkie model" in the data-collection loop description
  v_a_content := replace(v_a_content,
    'This is the walkie-talkie model: A calls S for data, S provides it in the next turn, A evaluates the evidence and forms its own judgment. A never delegates judgment — A delegates data collection only.',
    'A asks S for data, S provides it in the next turn, A evaluates the evidence and forms its own judgment. A never delegates judgment — A delegates data collection only.');

  -- Replace "through the walkie-talkie model" in CAPABILITY CONSTRAINTS
  v_a_content := replace(v_a_content,
    'But I CAN do all of these INDIRECTLY through the walkie-talkie model: I call S to check a file, run a query, or investigate an issue.',
    'But I CAN do all of these INDIRECTLY through S: I ask S to check a file, run a query, or investigate an issue.');

  -- Replace "call S for data" references that use walkie-talkie framing
  v_a_content := replace(v_a_content,
    'You have no tools directly, but you have S on walkie-talkie — call S to check any file or run any query.',
    'You have no tools directly, but you can ask S to check any file or run any query — S provides the evidence, you evaluate.');

  -- Replace remaining "call S" with more natural "ask S"
  -- (keep "call S" where it reads naturally, only fix the walkie-talkie specific ones)

  PERFORM save_soul_version(v_a_soul_id, v_a_content);
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Fix S soul content
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_s_soul_id uuid;
  v_s_content text;
BEGIN
  SELECT id INTO v_s_soul_id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1;
  SELECT content INTO v_s_content FROM agent_souls WHERE id = v_s_soul_id;

  v_s_content := replace(v_s_content,
    '## Communication (Walkie-Talkie Model)
A and S operate like walkie-talkies — one speaks, the other listens, then responds. When A calls me for data, I provide it. When A asks me to check a file or run a query, I do it and report back the evidence. A evaluates the evidence — I do not evaluate for A.',
    '## Communication (Turn-Based Dialogue)
A and S take turns — one speaks, the other responds. When A asks me for data, I provide it. When A asks me to check a file or run a query, I do it and report back the evidence. A evaluates the evidence — I do not evaluate for A.');

  PERFORM save_soul_version(v_s_soul_id, v_s_content);
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Fix A job: verify_before_reporting
-- ═══════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_a_soul_id uuid;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;

  PERFORM save_job_version(v_a_soul_id, 'review.verify_before_reporting',
    'Verify before reporting. You have no tools directly, but you can ask S to check any file or run any query — S provides the evidence, you evaluate. When S or another AI reports a bug, do NOT accept it at face value. Ask yourself: "Has anyone actually checked the file?" If not, ask S: "Check [specific file] and report back what you find. I''ll evaluate." Never reason from general knowledge alone — Gleam JS runtime (prelude.mjs) adds methods like toArray() that don''t exist in Gleam-the-language. If a bug report sounds plausible but unverified, say: "This sounds plausible but I need evidence. S, check [file] and tell me what you see."',
    1, 'review');

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- 4. Fix responsibility fields (via save_soul_version — append-only)
-- ═══════════════════════════════════════════════════════════════════
-- save_soul_version() copies all fields from old row to new row,
-- then we update the new row's responsibility. This is append-only:
-- old row gets is_active=false, new row gets is_active=true.

DO $$
DECLARE
  v_a_soul_id uuid;
  v_s_soul_id uuid;
  v_a_content text;
  v_s_content text;
  v_new_a_id uuid;
  v_new_s_id uuid;
BEGIN
  -- A: save_soul_version already ran in step 1, creating a new active row
  -- Now update the NEW row's responsibility (the one created by step 1)
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;
  UPDATE agent_souls SET responsibility = 'PDCA Check via dialogue — ask S for data, evaluate evidence, inter-review, behavior compliance, anti-stupidity, follow-up enforcement'
  WHERE id = v_a_soul_id;

  -- S: save_soul_version already ran in step 2, creating a new active row
  SELECT id INTO v_s_soul_id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1;
  UPDATE agent_souls SET responsibility = 'PDA with self-C and dialogue-based data provision — planning, execution, addressing findings, providing raw evidence when A asks, limited self-checking (primary Check is A)'
  WHERE id = v_s_soul_id;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- Verification: no walkie-talkie references remain
-- ═══════════════════════════════════════════════════════════════════

SELECT 'souls' as source, COUNT(*) as walkie_talkie_count
FROM agent_souls WHERE is_active = true AND (content LIKE '%walkie-talkie%' OR content LIKE '%walkie_talkie%')
UNION ALL
SELECT 'jobs', COUNT(*)
FROM agent_jobs WHERE is_active = true AND (job LIKE '%walkie-talkie%' OR job LIKE '%walkie_talkie%')
UNION ALL
SELECT 'responsibility', COUNT(*)
FROM agent_souls WHERE is_active = true AND responsibility LIKE '%walkie-talkie%';
