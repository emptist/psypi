-- agent_tasks: prioritized work items for each agent
-- A reminds S, S executes. Both can add new tasks.
-- Joined with agent_soul via soul_id

CREATE TABLE IF NOT EXISTS agent_tasks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  soul_id uuid NOT NULL REFERENCES agent_souls(id),
  task text NOT NULL,
  priority int NOT NULL,
  category text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_soul_id ON agent_tasks(soul_id);
CREATE INDEX IF NOT EXISTS idx_agent_tasks_priority ON agent_tasks(priority);

-- Autonomic tasks (A reminds S)
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Inter-review S code changes (triggered by psypi-commit tool)', 1, 'review' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Unblock stuck S tasks with specific information', 2, 'unblock' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Help S continue current work with next logical steps', 3, 'continue' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Suggest new tasks only when S has no in-progress work', 4, 'new_task' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Identify and suggest cleanup of stale tasks (>7 days)', 5, 'maintenance' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Check docs match code, suggest updates', 6, 'maintenance' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Find modules >100 lines that should be split', 7, 'quality' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Research competitors (openclaw, lobehub, etc.)', 8, 'research' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Read user files, save knowledge to memory', 9, 'learning' FROM agent_soul WHERE id_prefix = 'A';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Research business opportunities, draft proposals', 10, 'business' FROM agent_soul WHERE id_prefix = 'A';

-- Somatic tasks (S executes)
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'System-review codebase when directed by A', 1, 'review' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Perform inter-review on code changes', 1, 'review' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Execute unblock actions when stuck', 2, 'unblock' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Continue current task with A''s guidance', 3, 'continue' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Accept new tasks when no in-progress work', 4, 'new_task' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Close or re-prioritize stale tasks', 5, 'maintenance' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Update documentation to match code', 6, 'maintenance' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Refactor large modules into smaller ones', 7, 'quality' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Execute competitive research tasks', 8, 'research' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Save user knowledge to memory', 9, 'learning' FROM agent_soul WHERE id_prefix = 'S';
INSERT INTO agent_tasks (soul_id, task, priority, category)
SELECT id, 'Review and implement business proposals', 10, 'business' FROM agent_soul WHERE id_prefix = 'S';
