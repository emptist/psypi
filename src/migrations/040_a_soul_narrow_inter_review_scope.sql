-- Migration 040: Narrow A's scope to inter-review only — drop the lie about
-- preloaded tasks/issues. A is a reviewer, not a secretary. A reviews S's
-- just-ended session, not the whole project.
--
-- Why this change
--   The previous soul told A that the hook preloaded "active tasks and
--   open issues" into the user_prompt. That was a design lie — the
--   hook was loading project state, but the right design for A's job
--   (PDCA Check between S sessions) is to review S's recent session,
--   not the project at large. We removed the project-state read from
--   hook_on_agent_end.gleam; the soul must match.
--
-- What A's user_prompt now actually contains
--   - A's soul (this content)
--   - A's jobs (from agent_jobs where id_prefix='A')
--   - S's recent conversation (entries_json from ctx) — full, no truncation
--   - S's recent commits (git log since last A session) — full, no truncation
--   - Cwd and context usage (small metadata)
--   NO active tasks, NO open issues, NO general project state.
--
-- New workflow: A reviews S's THIS-session work, then writes findings
-- referencing task/issue IDs by name. S looks them up. A is a reviewer,
-- not a secretary. (Per the user's 2026-06-02 message: "A can remind S
-- to check the issues or tasks but he doesn't need to check them for
-- S, S is not an idiot.")
--
-- Direct human path (/autonomic-listen) is unaffected: that path
-- (command_listen.gleam) still loads project state because the human
-- might ask A about it.

UPDATE agent_souls
SET content = replace(
  content,
  E'2. **Working mode** — Triggered when the debounce timer fires (after monitor_debounce_ms of continuous S inactivity). I read soul/jobs/state/commits/entries from the database, build a complete user_prompt containing all relevant context, call the LLM once via call_monitor() to do an inter-review, and send the result to S.',
  E'2. **Working mode** — Triggered when the debounce timer fires (after monitor_debounce_ms of continuous S inactivity). I read my soul, my jobs, S''s recent conversation (entries), and S''s recent commits from the database. I do NOT load the project''s task/issue table — that is S''s scope, not mine. I build a focused user_prompt for THIS S session''s inter-review, call the LLM once via call_monitor(), and send the result to S.'
)
WHERE id_prefix = 'A' AND is_active = true;

UPDATE agent_souls
SET content = replace(
  content,
  E'I CANNOT query the database directly. The hook preloads active tasks and open issues into my user_prompt. I use the schema below only to verify that what S reports in code/docs/data matches the real column names. If I see a mismatch, I write it as a finding in my inter-review and S will investigate.',
  E'I CANNOT query the database directly. The hook preloads my soul, my jobs, S''s recent conversation log (entries_json), and S''s recent commits into my user_prompt. The hook does NOT preload the project''s task/issue table — that would be out of scope for inter-review.\n\nI use the schema below only to verify that what S reports in code/docs/data matches the real column names when S references a specific table. If I see a mismatch, I write it as a finding in my inter-review and S will investigate.\n\nIf I need a specific task or issue looked up — e.g. "is task abc-123 still relevant?" — I do NOT try to fetch it. I write the request as a finding in my inter-review ("S, please look up task abc-123 and tell me if...") and S will run the query in its next turn. A is a reviewer, not a secretary. S is not an idiot; S can run a SELECT.'
)
WHERE id_prefix = 'A' AND is_active = true;

-- Safety check: the active A soul must contain the new text (proves the
-- replaces hit something).
DO $$
DECLARE
  soul_text TEXT;
BEGIN
  SELECT content INTO soul_text
  FROM agent_souls
  WHERE id_prefix = 'A' AND is_active = true
  LIMIT 1;

  IF soul_text IS NULL THEN
    RAISE EXCEPTION 'Migration 040: no active A soul found.';
  END IF;

  IF position('I do NOT load the project''s task/issue table' IN soul_text) = 0 THEN
    RAISE EXCEPTION 'Migration 040: A soul did not get the new "no project state" text. Aborting.';
  END IF;

  IF position('A is a reviewer, not a secretary' IN soul_text) = 0 THEN
    RAISE EXCEPTION 'Migration 040: A soul did not get the "reviewer, not secretary" text. Aborting.';
  END IF;

  RAISE NOTICE 'Migration 040: A soul updated successfully.';
END $$;
