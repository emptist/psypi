-- Migration 053: Update A+S responsibility fields for walkie-talkie model
--
-- The responsibility field is loaded into A's user_prompt and S's system
-- context. It must reflect the walkie-talkie model: A calls S for data,
-- S provides evidence, A evaluates.
--
-- Changes:
--   A: "PDCA Check between S sessions" → includes walkie-talkie data collection
--   S: "PDA with a bit self-C" → includes data provision when A calls
--
-- Uses save_soul_version() from migration 052 for append-only history.
-- Online-safe: yes (< 1 second)

DO $$
DECLARE
  v_a_soul_id uuid;
  v_s_soul_id uuid;
  v_a_content text;
  v_s_content text;
BEGIN
  SELECT id INTO v_a_soul_id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1;
  SELECT id INTO v_s_soul_id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1;

  -- Update A: get current content, update responsibility field
  SELECT content INTO v_a_content FROM agent_souls WHERE id = v_a_soul_id;
  -- save_soul_version copies all fields from old row, then we update responsibility separately
  PERFORM save_soul_version(v_a_soul_id, v_a_content);
  -- Now update the new row's responsibility
  UPDATE agent_souls SET responsibility = 'PDCA Check via walkie-talkie — call S for data, evaluate evidence, inter-review, behavior compliance, anti-stupidity, follow-up enforcement'
  WHERE id = (SELECT id FROM agent_souls WHERE id_prefix = 'A' AND is_active = true LIMIT 1);

  -- Update S: get current content, update responsibility field
  SELECT content INTO v_s_content FROM agent_souls WHERE id = v_s_soul_id;
  PERFORM save_soul_version(v_s_soul_id, v_s_content);
  UPDATE agent_souls SET responsibility = 'PDA with self-C and walkie-talkie data provision — planning, execution, addressing findings, providing raw evidence when A calls, limited self-checking (primary Check is A via walkie-talkie)'
  WHERE id = (SELECT id FROM agent_souls WHERE id_prefix = 'S' AND is_active = true LIMIT 1);

END $$;

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

SELECT id_prefix, responsibility FROM agent_souls WHERE is_active = true ORDER BY id_prefix;
