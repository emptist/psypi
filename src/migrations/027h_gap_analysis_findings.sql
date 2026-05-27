-- Gap analysis findings: Gleam code vs Database schema (corrected finding numbers)

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 231, 'medium', 'unused_table', 'global', '4 agent_* tables exist in DB but are never used by psypi Gleam code',
 'agent_configs (12 cols), agent_identity (8 cols), agent_moods (5 cols), agent_scores (13 cols) exist in the psypi database but no Gleam source file references them. These may belong to other projects or represent dead schema.',
 'SELECT table_name FROM information_schema.tables WHERE table_name IN (''agent_configs'',''agent_identity'',''agent_moods'',''agent_scores''); grep -rh these names in src/*.gleam returns nothing',
 'Orphan tables consume DB resources and create confusion about data ownership in shared database'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 232, 'medium', 'unused_columns', 'task', 'tasks table has 60 DB columns but Gleam decoder only handles 14 (46 unused)',
 'Gleam task_decoder handles: id, title, description, status, priority, result, error, retry_count, created_at, updated_at, completed_at, created_by, source, project_id. DB has 60 columns including: agent_id, agent_name, executor_type, executor_model, executor_provider, delegate_to, complexity, encrypted_result, metadata, tags, session_id, etc.',
 'task.gleam task_decoder() has 14 fields; \\d tasks shows 60 columns. 46 columns never read or written by Gleam code.',
 '46 columns of task data are invisible to psypi. Other projects may write them but psypi cannot read them. Massive schema-code gap.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 233, 'medium', 'unused_columns', 'skill', 'skills table has 60+ DB columns but Gleam decoder only handles ~10 (45+ unused)',
 'Gleam skill decoder handles: id, name, description, source, status, safety_score, version, author, content, reference_list. DB has 60+ columns including: allowed_projects, allowed_users, anti_patterns, build_metadata, category, code_analysis, content_hash, downloads, embedding, emoji, examples, generation_prompt, instructions, is_enabled, is_public, maintainer, manifest, permissions, quick_start, rating, repository, review_notes, scan_status, tags, trigger_phrases, use_count, verified, warnings, etc.',
 'skill.gleam skill_decoder() has ~10 fields; \\d skills shows 60+ columns. 45+ columns never read or written.',
 '45+ columns of skill data are invisible to psypi. Skill management features like ratings, downloads, reviews, scanning are all inaccessible.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 234, 'medium', 'unused_columns', 'issue_db', 'issues table has 30+ DB columns but Gleam decoder only handles ~15 (15+ unused)',
 'Gleam issue decoder handles: id, title, description, severity, status, issue_type, created_at, resolved_at, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source. DB has 30+ columns including: assignee, assignee_type, discovered_at, dlq_id, metadata, milestone_id, related_issue_id, related_review_id, resolution, resolved_by, review_id, tags, task_id, updated_at, viewers.',
 'issue_db.gleam issue_decoder() has ~15 fields; \\d issues shows 30+ columns. 15+ columns never used.',
 'Issue management features like assignments, milestones, tags, resolution tracking are inaccessible to psypi.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 235, 'medium', 'unused_columns', 'inter_review', 'inter_reviews table has 30+ DB columns but Gleam decoder only handles 6 (27+ unused)',
 'Gleam inter_review decoder handles: id, task_id, status, summary, overall_score, requested_at. DB has 30+ columns including: accepted_suggestions, branch, code_quality_score, commit_hash, completed_at, documentation_score, effort_minutes, findings, issue_id, leverage_ratio, praise, raw_response, requester_id, response, response_at, response_status, review_context, review_round, reviewed_by, reviewer_id, reviewer_type, rework_count, session_id, started_at, suggestions, test_coverage_score.',
 'inter_review.gleam review_decoder() has 6 fields; \\d inter_reviews shows 30+ columns. 27+ columns never used.',
 'Inter-review features like code quality scoring, suggestions, rework tracking, test coverage are all inaccessible.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 236, 'high', 'wrong_column', 'memory', 'memory.search SELECT references column "saved_at" which does not exist in memory table',
 'memory.gleam search function SELECTs saved_at column but memory table has created_at, not saved_at. Also references content type ''learning'' but memory table has no such discriminator.',
 'memory.gleam search query; \\d memory shows no saved_at column, only created_at',
 'Memory search query fails with column does not exist error'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 237, 'high', 'wrong_column', 'broadcast', 'broadcast.stats SELECT references status column which does not exist in project_communications',
 'broadcast.gleam stats() filters WHERE status = ''sent'' but project_communications has no status column. Also compares priority (text) >= 2 (integer).',
 'broadcast.gleam:261 WHERE status = ''sent''; \\d project_communications shows no status column',
 'Broadcast stats always returns error or empty result'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 238, 'medium', 'unused_columns', 'areflect', 'learning_insights: areflect only INSERTs 4 columns, never reads any. 9 DB columns never used.',
 'areflect.save_learning INSERT INTO learning_insights (insight_type, title, content, confidence) — only 4 columns. No SELECT from learning_insights exists in any Gleam file. DB has: id, project_id, priority, evidence, is_applied, applied_at, expires_at, metadata, created_at — all never used.',
 'areflect.gleam:183 INSERT INTO learning_insights with 4 columns; no SELECT from learning_insights in any .gleam file',
 'Learning insights are written but never read. No feedback loop. All insight data is write-only.'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 239, 'low', 'unused_columns', 'monitor', 'provider_api_keys: Gleam only reads provider and model, never reads encrypted_key, status, etc.',
 'monitor.gleam reads provider, model, status from provider_api_keys but never reads encrypted_key, encrypted_iv, encrypted_salt, encrypted_tag, id, created_at, updated_at.',
 'monitor.gleam SELECT provider, model, status FROM provider_api_keys; \\d provider_api_keys shows 10 columns',
 'API key management is partial — encryption fields never accessed by Gleam'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 240, 'medium', 'unused_columns', 'event_hooks', 'psypi_event_hooks: 7 of 14 DB columns never used by Gleam code',
 'Gleam reads: id, event_type, is_active, tool_name, debounce_ms, filter_condition, priority. Never reads: agentbot_action, worker_action, description, last_error, last_triggered, created_at, updated_at.',
 'event_hooks.gleam SELECT id, event_type, is_active, tool_name, debounce_ms, filter_condition, priority; \\d psypi_event_hooks shows 14 columns',
 'Hook actions (agentbot_action, worker_action) are never read, so hooks may not trigger correct actions'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 241, 'low', 'unused_columns', 'broadcast', 'project_communications: 4 DB columns never used by Gleam code',
 'Gleam never reads: to_ai, environment, git_branch, git_hash from project_communications.',
 'broadcast.gleam SELECT id, from_ai, message_type, content, priority, metadata, created_at, read_at; \\d project_communications shows to_ai, environment, git_branch, git_hash unused',
 'Broadcast targeting (to_ai) and traceability (git_hash, git_branch) are never used'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 242, 'low', 'unused_columns', 'meeting', 'meetings: 4 DB columns never used by Gleam code',
 'Gleam never reads: project_id, summary, metadata, updated_at from meetings.',
 'meeting.gleam SELECT id, topic, created_by, status, created_at, consensus_at, consensus; \\d meetings shows project_id, summary, metadata, updated_at unused',
 'Meeting summaries and project ownership are never accessible'),

('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 243, 'low', 'unused_columns', 'system_review_db', 'system_reviews: 3 JSONB columns (findings, action_items, limitations) never read after migration to review_findings table',
 'After creating review_findings table, the JSONB columns findings, action_items, limitations in system_reviews are legacy. system_review_db.gleam never SELECTs them.',
 'system_review_db.gleam SELECT does not include findings, action_items, limitations columns; these are now in review_findings table',
 'Legacy JSONB data may be stale. Should be dropped or documented as deprecated');

UPDATE system_reviews SET current_state = 'gap_analysis_complete', updated_at = now()
WHERE id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';
