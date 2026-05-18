-- psypi_event_hooks: Track all Pi event hooks for Monitor
-- Monitor reads this table to know what events it should monitor

CREATE TABLE IF NOT EXISTS psypi_event_hooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name TEXT NOT NULL UNIQUE,
  hook_status TEXT DEFAULT 'active' CHECK (hook_status IN ('active', 'inactive', 'error', 'experimental')),
  monitor_action TEXT NOT NULL,
  agentbot_action TEXT,
  injection_enabled BOOLEAN DEFAULT FALSE,
  description TEXT,
  last_triggered TIMESTAMP,
  trigger_count INT DEFAULT 0,
  error_count INT DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_event_hooks_status ON psypi_event_hooks(hook_status);
CREATE INDEX IF NOT EXISTS idx_event_hooks_name ON psypi_event_hooks(event_name);

-- Populate with all current hooks
INSERT INTO psypi_event_hooks (event_name, hook_status, monitor_action, agentbot_action, injection_enabled, description)
VALUES
  ('session_start', 'active', 'Initialize, record model, health check', NULL, TRUE, 'Session begins - record model, check health, set status'),
  ('before_agent_start', 'active', 'Read DB notifications, inject into system prompt', 'Work on tasks', TRUE, 'Before agent loop - bridge Monitor to Agentbot via notifications'),
  ('agent_start', 'active', 'Track agent activity (silent)', NULL, FALSE, 'Agent loop starts - log start'),
  ('agent_end', 'active', 'Track session completion (silent)', NULL, FALSE, 'Agent loop ends - log end, analyze'),
  ('tool_call', 'active', 'Safety check, activity log, auto-backup', NULL, TRUE, 'Before tool - block dangerous ops, log, auto-backup'),
  ('tool_result', 'active', 'Detect errors, create notification, auto-file issue', 'Get result', TRUE, 'After tool - detect errors, notify Agentbot, file issues'),
  ('model_select', 'active', 'Record model change to DB', 'Adapt to model', FALSE, 'Model changes - record for Monitor tracking'),
  ('tool_execution_start', 'inactive', 'Log tool start', NULL, FALSE, 'Tool execution begins - monitor progress'),
  ('tool_execution_update', 'inactive', 'Monitor progress', NULL, FALSE, 'Tool execution updates - track progress'),
  ('tool_execution_end', 'inactive', 'Log tool end', NULL, FALSE, 'Tool execution ends - log completion'),
  ('session_shutdown', 'inactive', 'Final report, save state', 'Save state', FALSE, 'Session ends - final report, cleanup'),
  ('session_before_switch', 'inactive', 'Validate switch safe', 'Save state', FALSE, 'Before switch - validate safe'),
  ('session_before_fork', 'inactive', 'Monitor fork', 'Prepare', FALSE, 'Before fork - prepare'),
  ('session_before_compact', 'inactive', 'Review compaction', 'Summarize', FALSE, 'Before compaction - review'),
  ('session_compact', 'inactive', 'Monitor quality', 'Receive summary', FALSE, 'Compaction runs - monitor quality'),
  ('session_before_tree', 'inactive', 'Validate target', 'Prepare', FALSE, 'Before tree nav - validate'),
  ('session_tree', 'inactive', 'Log navigation', 'Navigate', FALSE, 'Tree navigation - log'),
  ('turn_start', 'inactive', 'Log turn (silent)', NULL, FALSE, 'Turn starts - log'),
  ('turn_end', 'inactive', 'Log turn, analyze (silent)', NULL, FALSE, 'Turn ends - log, analyze'),
  ('message_start', 'inactive', 'Log message', 'Process', FALSE, 'Message starts - log'),
  ('message_update', 'inactive', 'Log message update', 'Receive', FALSE, 'Message updates - log'),
  ('message_end', 'inactive', 'Log message end, analyze', 'Complete', FALSE, 'Message ends - complete, analyze'),
  ('before_provider_request', 'inactive', 'Log, debug request', NULL, FALSE, 'Before LLM call - debug'),
  ('after_provider_response', 'inactive', 'Log, detect rate limits', NULL, TRUE, 'After LLM response - detect rate limits'),
  ('thinking_level_select', 'inactive', 'Log thinking level change', 'Adapt', FALSE, 'Thinking changes - log'),
  ('user_bash', 'inactive', 'Log bash input', 'Execute', FALSE, 'Bash input - log'),
  ('input', 'inactive', 'Log user input', 'Process', FALSE, 'User input - log'),
  ('context', 'inactive', 'Detect context changes', 'Adapt', FALSE, 'Context changes - detect changes'),
  ('renderCall', 'inactive', 'UI update (silent)', NULL, FALSE, 'Tool call render - UI'),
  ('renderResult', 'inactive', 'UI update (silent)', NULL, FALSE, 'Tool result render - UI')
ON CONFLICT (event_name) DO UPDATE SET
  monitor_action = EXCLUDED.monitor_action,
  agentbot_action = EXCLUDED.agentbot_action,
  injection_enabled = EXCLUDED.injection_enabled,
  description = EXCLUDED.description,
  updated_at = NOW();
