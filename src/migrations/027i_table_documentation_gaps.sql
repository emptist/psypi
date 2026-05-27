-- Update table_documentation with gap analysis context
-- Key: any AI must be able to understand which tables psypi uses, what gaps exist,
-- and how to verify findings against reality.

-- First: document the 4 unused agent_* tables
INSERT INTO table_documentation (table_name, purpose, usage_context, key_columns, related_tables, ai_can_modify, created_by, notes, tags)
VALUES
('agent_configs', 'Agent configuration storage. NOT used by psypi Gleam code. Likely belongs to another project (nezha/nupi) in shared database. Empty (0 rows).', 'Shared database table. psypi uses agent_souls and agent_identities instead.', '{"id": "UUID PK", "project_id": "text NOT NULL", "agent_id": "text NOT NULL", "name": "text", "role": "text", "model": "text", "capabilities": "jsonb", "tools": "jsonb", "version": "integer"}'::jsonb, ARRAY['agent_souls', 'agent_identities'], true, 'trae-ai-gap-analysis', 'Empty table. No Gleam code references it. May be from nezha project. Has project_id column.', ARRAY['agent', 'unused', 'shared-db']),
('agent_identity', 'Agent identity registry. NOT used by psypi Gleam code. Different from agent_identities (plural) which psypi does use. Empty (0 rows).', 'Shared database table. psypi uses agent_identities (plural) table instead.', '{"id": "UUID PK", "agent_name": "uuid (unusual type for name column)", "display_name": "text", "description": "text", "capabilities": "ARRAY", "created_at": "timestamptz", "last_seen_at": "timestamptz", "metadata": "jsonb"}'::jsonb, ARRAY['agent_identities'], true, 'trae-ai-gap-analysis', 'Empty table. agent_name is uuid type (suspicious). No Gleam code references it.', ARRAY['agent', 'unused', 'shared-db']),
('agent_moods', 'Agent mood tracking. NOT used by psypi Gleam code. Empty (0 rows).', 'Shared database table. No psypi module reads or writes this table.', '{"id": "integer PK", "agent_id": "varchar", "mood": "varchar", "context": "text", "timestamp": "timestamp without tz"}'::jsonb, ARRAY[]::text[], true, 'trae-ai-gap-analysis', 'Empty table. Uses timestamp without tz (inconsistent with other tables using timestamptz). No project_id column.', ARRAY['agent', 'unused', 'shared-db']),
('agent_scores', 'Agent performance scoring. NOT used by psypi Gleam code. Empty (0 rows).', 'Shared database table. No psypi module reads or writes this table.', '{"id": "UUID PK", "agent_id": "varchar", "commits_count": "integer", "tasks_completed": "integer", "tasks_failed": "integer", "meeting_contributions": "integer", "code_reviews": "integer", "composite_score": "numeric", "is_protected": "boolean"}'::jsonb, ARRAY[]::text[], true, 'trae-ai-gap-analysis', 'Empty table. No project_id column. Likely from nezha scoring system.', ARRAY['agent', 'unused', 'shared-db'])
ON CONFLICT (table_name) DO UPDATE SET
  purpose = EXCLUDED.purpose,
  usage_context = EXCLUDED.usage_context,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  notes = EXCLUDED.notes,
  tags = EXCLUDED.tags,
  updated_at = now();

-- Update key psypi tables with gap analysis info
-- tasks: massive gap (60 cols in DB, 14 in Gleam)
UPDATE table_documentation SET
  notes = 'GAP: 60 DB columns but Gleam task_decoder only handles 14. 46 columns never read/written by psypi including: agent_id, agent_name, executor_type, executor_model, executor_provider, delegate_to, complexity, encrypted_result, metadata, tags, session_id, type, assigned_to, category, error_category, consecutive_failures, is_stuck, watchdog_kills, template_id, progress_percent, pause_reason. Other projects (nezha, nupi) may write these columns. Gleam decoders need ::text casts for: id (uuid), result (jsonb), created_at/updated_at/completed_at (timestamptz), project_id (uuid).',
  key_columns = '{"id": "UUID PK — needs ::text cast", "title": "text NOT NULL", "status": "text NOT NULL — CHECK: PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE", "priority": "int4", "result": "jsonb — needs ::text cast", "project_id": "UUID NOT NULL — needs ::text cast", "created_at": "timestamptz — needs ::text cast", "updated_at": "timestamptz — needs ::text cast", "completed_at": "timestamptz — needs ::text cast"}'::jsonb,
  updated_at = now()
WHERE table_name = 'tasks';

-- skills: massive gap (60+ cols in DB, ~10 in Gleam)
UPDATE table_documentation SET
  notes = 'GAP: 60+ DB columns but Gleam skill_decoder only handles ~10. 45+ columns never read/written by psypi including: allowed_projects, allowed_users, anti_patterns, build_metadata, category, code_analysis, content_hash, downloads, embedding, emoji, examples, generation_prompt, instructions, is_enabled, is_public, maintainer, manifest, permissions, quick_start, rating, repository, review_notes, scan_status, tags, trigger_phrases, use_count, verified, warnings. Gleam decoders need ::text casts for: id (uuid), content (jsonb), reference_list (jsonb), created_at (timestamptz).',
  key_columns = '{"id": "UUID PK — needs ::text cast", "name": "text NOT NULL UNIQUE", "source": "text — CHECK: clawhub/local/generated/imported/ai-built (Gleam missing ai-built variant)", "status": "text — CHECK: pending/active/disabled/reviewing/deprecated (Gleam missing reviewing/deprecated)", "content": "jsonb — needs ::text cast", "reference_list": "jsonb — needs ::text cast", "created_at": "timestamptz — needs ::text cast"}'::jsonb,
  updated_at = now()
WHERE table_name = 'skills';

-- issues: gap (30+ cols in DB, ~15 in Gleam)
UPDATE table_documentation SET
  notes = 'GAP: 30+ DB columns but Gleam issue_decoder handles ~15. 15+ columns never used by psypi: assignee, assignee_type, discovered_at, dlq_id, metadata, milestone_id, related_issue_id, related_review_id, resolution, resolved_by, review_id, tags, task_id, updated_at, viewers. Gleam INSERT in monitor_ai.gleam uses wrong column name "type" instead of "issue_type". Gleam INSERT in areflect.gleam missing project_id (NOT NULL). Needs ::text casts for: id, created_at, resolved_at.',
  key_columns = '{"id": "UUID PK — needs ::text cast", "title": "text NOT NULL", "severity": "text NOT NULL — CHECK: critical/high/medium/low/cosmetic/info", "status": "text NOT NULL — CHECK: open/in_progress/resolved/closed/acknowledged/wont_fix/duplicate/reopened", "issue_type": "text NOT NULL — CHECK: bug/feature/question/enhancement/proposal (Gleam missing proposal)", "created_at": "timestamptz — needs ::text cast", "project_id": "UUID NOT NULL"}'::jsonb,
  updated_at = now()
WHERE table_name = 'issues';

-- inter_reviews: gap (30+ cols in DB, 6 in Gleam)
UPDATE table_documentation SET
  notes = 'GAP: 30+ DB columns but Gleam review_decoder only handles 6. 27+ columns never used by psypi: accepted_suggestions, branch, code_quality_score, commit_hash, completed_at, documentation_score, effort_minutes, findings, issue_id, leverage_ratio, praise, raw_response, requester_id, response, response_at, response_status, review_context, review_round, reviewed_by, reviewer_id, reviewer_type, rework_count, session_id, started_at, suggestions, test_coverage_score. Needs ::text casts for: id, task_id, requested_at.',
  updated_at = now()
WHERE table_name = 'inter_reviews';

-- project_communications: wrong column reference
UPDATE table_documentation SET
  notes = 'GAP: broadcast.gleam stats() references non-existent "status" column and compares text priority >= 2 (integer). Table has no status column. Priority is text CHECK: low/normal/high/critical. 4 columns never used: to_ai, environment, git_branch, git_hash. Needs ::text casts for: id, created_at, read_at.',
  key_columns = '{"id": "UUID PK — needs ::text cast", "from_ai": "text NOT NULL", "to_ai": "text (never read by Gleam)", "message_type": "text NOT NULL — CHECK: task/review/feedback/status/question/answer/notification/broadcast", "priority": "text — CHECK: low/normal/high/critical (NOT integer!)", "created_at": "timestamptz — needs ::text cast", "read_at": "timestamptz — needs ::text cast"}'::jsonb,
  updated_at = now()
WHERE table_name = 'project_communications';

-- learning_insights: write-only, never read
UPDATE table_documentation SET
  notes = 'GAP: Write-only table. areflect.gleam only INSERTs 4 columns (insight_type, title, content, confidence). No SELECT from learning_insights exists in any Gleam file. 9 DB columns never used: id, project_id, priority, evidence, is_applied, applied_at, expires_at, metadata, created_at. No feedback loop — insights are stored but never consumed.',
  updated_at = now()
WHERE table_name = 'learning_insights';

-- memory: SELECT * with missing casts
UPDATE table_documentation SET
  notes = 'GAP: memory.gleam uses SELECT * which returns uuid/timestamptz/jsonb columns without ::text casts. 9 DB columns never used by Gleam: id, project_id, embedding, has_sensitive, metadata, session_id, updated_at, viewers, created_at (used in ORDER BY but not decoded). Memory has RLS policy (memory_project_isolation) and embedding vector index.',
  key_columns = '{"id": "UUID PK — needs ::text cast", "content": "text NOT NULL", "source": "text", "tags": "text[]", "importance": "int CHECK 1-10", "agent_id": "varchar(100)", "created_at": "timestamptz — needs ::text cast", "project_id": "UUID — has RLS policy"}'::jsonb,
  updated_at = now()
WHERE table_name = 'memory';

-- psypi_event_hooks: 7 of 14 columns never used
UPDATE table_documentation SET
  notes = 'GAP: 7 of 14 DB columns never used by Gleam: agentbot_action, worker_action, description, last_error, last_triggered, created_at, updated_at. Hook actions (agentbot_action, worker_action) are never read, so hooks may not trigger correct actions. Needs ::text cast for id (uuid).',
  updated_at = now()
WHERE table_name = 'psypi_event_hooks';

-- system_reviews: legacy JSONB columns
UPDATE table_documentation SET
  notes = 'After migration to review_findings table, the JSONB columns findings, action_items, limitations are legacy and never read by system_review_db.gleam. Should be deprecated or dropped. Needs ::text casts for: id, project_id, related_issue_id, follow_up_due, created_at, updated_at, completed_at.',
  updated_at = now()
WHERE table_name = 'system_reviews';

-- provider_api_keys: partial access
UPDATE table_documentation SET
  notes = 'GAP: Gleam only reads provider, model, status. Never reads encrypted_key, encrypted_iv, encrypted_salt, encrypted_tag, id, created_at, updated_at. API key encryption fields are never accessed by Gleam code.',
  updated_at = now()
WHERE table_name = 'provider_api_keys';

-- meetings: 4 columns never used
UPDATE table_documentation SET
  notes = 'GAP: 4 DB columns never used by Gleam: project_id, summary, metadata, updated_at. Meeting summaries and project ownership are never accessible. Needs ::text casts for: id, created_at, consensus_at.',
  updated_at = now()
WHERE table_name = 'meetings';

-- meeting_opinions: 1 column never used
UPDATE table_documentation SET
  notes = 'GAP: updated_at column never used by Gleam. Needs ::text casts for: id, meeting_id, created_at.',
  updated_at = now()
WHERE table_name = 'meeting_opinions';

-- notifications: missing casts
UPDATE table_documentation SET
  notes = 'Needs ::text casts for: id (uuid), created_at (timestamptz), read_at (timestamptz).',
  updated_at = now()
WHERE table_name = 'notifications';

-- code_versions: missing casts
UPDATE table_documentation SET
  notes = 'Needs ::text casts for: id (uuid), saved_at (timestamptz). get_code_versions() function returns TABLE(id uuid, ..., saved_at timestamptz) — also needs casts.',
  updated_at = now()
WHERE table_name = 'code_versions';

-- psypi_config: 4 columns never used
UPDATE table_documentation SET
  notes = 'GAP: 4 DB columns never used by Gleam: created_at, description, encrypted, updated_at. Config is read fresh on every agent_end.',
  updated_at = now()
WHERE table_name = 'psypi_config';

-- activity_log: check usage
UPDATE table_documentation SET
  notes = 'Used by monitor_ai.gleam for activity tracking. Verify all column casts are present.',
  updated_at = now()
WHERE table_name = 'activity_log';

-- agent_identities: check usage
UPDATE table_documentation SET
  notes = 'Used by agent_identity.gleam. Needs ::text casts for: id (uuid), created_at (timestamptz), last_seen (timestamptz).',
  updated_at = now()
WHERE table_name = 'agent_identities';

-- agent_souls: check usage
UPDATE table_documentation SET
  notes = 'Used by agent_identity.gleam. Needs ::text cast for: id (uuid).',
  updated_at = now()
WHERE table_name = 'agent_souls';

-- agent_sessions: check usage
UPDATE table_documentation SET
  notes = 'Used by session.gleam. Needs ::text casts for: id (uuid), created_at (timestamptz), last_active (timestamptz).',
  updated_at = now()
WHERE table_name = 'agent_sessions';

-- agent_prefixes: check usage
UPDATE table_documentation SET
  notes = 'Used by agent_identity.gleam. Needs ::text cast for: id (uuid).',
  updated_at = now()
WHERE table_name = 'agent_prefixes';

-- agent_jobs: check usage
UPDATE table_documentation SET
  notes = 'Used by agent_job.gleam. Needs ::text casts for: id (uuid), created_at (timestamptz), updated_at (timestamptz), started_at (timestamptz), completed_at (timestamptz).',
  updated_at = now()
WHERE table_name = 'agent_jobs';
