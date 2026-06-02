-- agent_jobs: prioritized work items for each agent soul
-- A reviews (PDCA Check), S executes (PDCA Do). Both can add new jobs.
-- Joined with agent_soul via soul_id
-- NOTE: called 'agent_jobs' not 'agent_tasks' to avoid confusion with the user-facing 'tasks' table
--
-- Responsibility split (also enforced by agent_souls.content and AGENTS.md):
--   A  -> Inter-review ONLY (PDCA Check between S sessions)
--   S  -> System-review ONLY (when A or user explicitly asks)
--   A NEVER does system-review; S NEVER does inter-review.
--   External AI agents (invited by user) may also do system-reviews.

CREATE TABLE IF NOT EXISTS agent_jobs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  soul_id uuid NOT NULL REFERENCES agent_souls(id),
  job text NOT NULL,
  priority int NOT NULL,
  category text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_jobs_soul_id ON agent_jobs(soul_id);
CREATE INDEX IF NOT EXISTS idx_agent_jobs_priority ON agent_jobs(priority);

-- Autonomic jobs (A does PDCA Check)
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Inter-review: PDCA Check between S sessions — review whatever S produced this cycle (code, docs, data, decisions). Not gated on commits, not 1:1 with tasks. Results MUST go to inter_reviews table with review_id referenced in message to S.', 1, 'review' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Self-monitor: when call_monitor() returns no data, when inter_review.save() fails, when ctx state looks weird (no entries, no cwd, missing callbacks), or when you find you cannot do something you expected to do — report the anomaly to S via pi.sendMessage(..., triggerTurn: true) so S can investigate. Be specific: what you tried, what you expected, what you got. Do NOT wait for the human. S is the fix-it agent. The /autonomic-listen tool is debug-only.', 1, 'self_monitor' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Review S behavior: did S report issues before fixing? did S plan before acting? did S update docs, skills, table_documentation after changes? Did S follow the closed loop (findings→issues→plans→tasks)?', 2, 'behavior' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Anti-stupidity: catch dangerous S behavior (fake Gleam, no FFI policy, data loss, etc.)', 3, 'safety' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Unblock stuck S jobs with specific information', 4, 'unblock' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Suggest doer-jobs to S when context is right; A decides whether to suggest, S decides whether to execute', 5, 'suggestion' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Identify stale S tasks (>7 days inactive), suggest cleanup or reprioritization', 6, 'maintenance' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Review own soul, responsibilities, and jobs definitions — do they still match reality? Update if stale or wrong', 7, 'definition' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Check review findings have corresponding issues: every significant finding should become an issue with root cause analysis', 8, 'closed_loop' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Check issues have discussion and plan: issues should have comments with investigation and action plan. If missing, add analysis or suggest plan', 9, 'closed_loop' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Check planned issues have tasks: when an issue has a sound plan, verify tasks exist. If not, create tasks or prompt S to create them', 10, 'closed_loop' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Check task execution follow-up: verify S addressed previous review findings. If not acted upon, escalate. No unaddressed findings should slip through', 11, 'closed_loop' FROM agent_souls WHERE id_prefix = 'A';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Check if issue discussion needs a meeting: when an issue has conflicting views or needs structured A-S dialogue, convene a meeting via psypi-meeting-add. Meetings produce consensus that feeds back into the issue plan', 12, 'closed_loop' FROM agent_souls WHERE id_prefix = 'A';

-- Somatic jobs (S does PDCA Do)
-- System-review is S's exclusive responsibility, ONLY when A or the user asks.
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Address A inter-review findings: read A feedback from inter_reviews, act on suggestions, improve code quality', 1, 'behavior' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'CRITICAL: Never create pi_*.gleam modules. Never write JS code as Gleam string literals. If you need JS interop, use .mjs files with @external FFI. Violating this rule causes 99% of all bugs in this codebase.', 1, 'quality' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'System-review (terminal monitoring): when directed by A or user, perform comprehensive review of entire system — codebase architecture, DB schema integrity, type coverage, doc completeness, code duplication, missing Gleam types, tech debt. Results to system_reviews + review_findings tables.', 1, 'review' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Report issues before attempting fixes. Plan before taking actions. Update docs, skills, and table_documentation after changes.', 2, 'behavior' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Execute unblock actions when stuck', 2, 'unblock' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Continue current job with A''s guidance', 3, 'continue' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Accept new jobs when no in-progress work', 4, 'new_job' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Accept new tasks when no in-progress work', 5, 'new_task' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Close or re-prioritize stale jobs', 6, 'maintenance' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Update documentation to match code', 7, 'maintenance' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Refactor large modules into smaller ones', 8, 'quality' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Execute competitive research tasks when suggested by A', 9, 'research' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Save user knowledge to memory', 10, 'learning' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Implement business proposals when suggested by A', 11, 'business' FROM agent_souls WHERE id_prefix = 'S';
INSERT INTO agent_jobs (soul_id, job, priority, category)
SELECT id, 'Review own soul, responsibilities, and jobs definitions - do they still match reality? Update if stale or wrong', 12, 'definition' FROM agent_souls WHERE id_prefix = 'S';
