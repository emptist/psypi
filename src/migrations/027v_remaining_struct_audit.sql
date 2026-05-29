-- 027v_remaining_struct_audit.sql
-- Add remaining psypi-used tables to struct_field_inventory

-- ============================================================================
-- skills: 55 DB columns, 12 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('skills', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String (ok with node-postgres)'),
('skills', 'name', 'text', 'NO', true, 'name', 'String', 'ok', NULL),
('skills', 'description', 'text', 'YES', true, 'description', 'Option(String)', 'ok', NULL),
('skills', 'source', 'text', 'NO', true, 'source', 'SkillSource', 'enum_gap', 'Missing AiBuilt variant'),
('skills', 'status', 'text', 'NO', true, 'status', 'SkillStatus', 'ok', NULL),
('skills', 'safety_score', 'integer', 'YES', true, 'safety_score', 'Int', 'ok', NULL),
('skills', 'version', 'text', 'NO', true, 'version', 'String', 'ok', NULL),
('skills', 'author', 'text', 'YES', true, 'author', 'Option(String)', 'ok', NULL),
('skills', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast (done in query)'),
('skills', 'content', 'jsonb', 'YES', true, 'content', 'Option(String)', 'type_mismatch', 'jsonb decoded as String. Query uses ::text cast.'),
('skills', 'reference_list', 'jsonb', 'YES', true, 'reference_list', 'Option(String)', 'type_mismatch', 'jsonb decoded as String. Query uses ::text cast.'),
-- skills: columns NOT in Gleam struct (43 columns)
('skills', 'project_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Project ownership'),
('skills', 'external_id', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'External reference'),
('skills', 'repository', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Repository URL'),
('skills', 'tags', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Skill tags'),
('skills', 'scan_status', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', '5-value enum, no Gleam type'),
('skills', 'verified', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Verification flag'),
('skills', 'downloads', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Download count'),
('skills', 'rating', 'numeric', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Rating 0-5'),
('skills', 'approved_by', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Approver identity'),
('skills', 'approved_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Approval time'),
('skills', 'rejection_reason', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Rejection reason'),
('skills', 'is_enabled', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Enable/disable flag'),
('skills', 'is_public', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Public visibility'),
('skills', 'allowed_users', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Access control'),
('skills', 'allowed_projects', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Project access'),
('skills', 'use_count', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Usage tracking'),
('skills', 'last_used_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Last usage time'),
('skills', 'installed_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Install time'),
('skills', 'warnings', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Warning list'),
('skills', 'issues', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Issue list'),
('skills', 'permissions', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Permission list'),
('skills', 'code_analysis', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Code analysis data'),
('skills', 'review_notes', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review notes'),
('skills', 'reviewed_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review time'),
('skills', 'reviewed_by', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Reviewer identity'),
('skills', 'review_status', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', '6-value enum, no Gleam type'),
('skills', 'auto_review_score', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Auto review score'),
('skills', 'manual_review_required', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Manual review flag'),
('skills', 'instructions', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Skill instructions'),
('skills', 'manifest', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Skill manifest'),
('skills', 'content_hash', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Content hash'),
('skills', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Update tracking'),
('skills', 'builder', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Builder identity'),
('skills', 'maintainer', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Maintainer identity'),
('skills', 'build_metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Build metadata'),
('skills', 'generation_prompt', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'AI generation prompt'),
('skills', 'category', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Skill category'),
('skills', 'trigger_phrases', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Trigger phrases'),
('skills', 'anti_patterns', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Anti-patterns'),
('skills', 'quick_start', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Quick start guide'),
('skills', 'examples', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Usage examples'),
('skills', 'embedding', 'USER-DEFINED', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Vector embedding'),
('skills', 'viewers', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Access control'),
('skills', 'emoji', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Display emoji'),
('skills', 'reference_list', 'jsonb', 'YES', false, NULL, NULL, 'duplicate', 'Already counted above in Gleam fields'),
('skills', 'references_json', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'References JSON');

-- ============================================================================
-- meetings: 11 DB columns, 7 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('meetings', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('meetings', 'topic', 'text', 'NO', true, 'topic', 'String', 'ok', NULL),
('meetings', 'status', 'text', 'NO', true, 'status', 'MeetingStatus', 'enum_gap', 'Pending variant not in DB CHECK'),
('meetings', 'created_by', 'text', 'NO', true, 'created_by', 'String', 'ok', NULL),
('meetings', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('meetings', 'consensus_at', 'timestamptz', 'YES', true, 'consensus_at', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast'),
('meetings', 'consensus', 'text', 'YES', true, 'consensus', 'Option(String)', 'ok', NULL),
('meetings', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Meeting metadata'),
('meetings', 'project_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Project ownership'),
('meetings', 'summary', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Meeting summary'),
('meetings', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Update tracking');

-- ============================================================================
-- meeting_opinions: 8 DB columns, 6 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('meeting_opinions', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('meeting_opinions', 'meeting_id', 'uuid', 'NO', true, 'meeting_id', 'String', 'type_mismatch', 'uuid as String'),
('meeting_opinions', 'author', 'text', 'NO', true, 'author', 'String', 'ok', NULL),
('meeting_opinions', 'perspective', 'text', 'NO', true, 'perspective', 'String', 'ok', NULL),
('meeting_opinions', 'reasoning', 'text', 'YES', true, 'reasoning', 'Option(String)', 'ok', NULL),
('meeting_opinions', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('meeting_opinions', 'position', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', '3-value enum (support/oppose/neutral), no Gleam type'),
('meeting_opinions', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Update tracking');

-- ============================================================================
-- project_communications: 13 DB columns, no Gleam struct (only raw queries)
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('project_communications', 'id', 'uuid', 'NO', false, NULL, NULL, 'no_gleam_struct', 'No Gleam struct for project_communications'),
('project_communications', 'project_id', 'uuid', 'NO', false, NULL, NULL, 'no_gleam_struct', 'Project ownership'),
('project_communications', 'from_ai', 'text', 'NO', false, NULL, NULL, 'no_gleam_struct', 'Sender identity'),
('project_communications', 'to_ai', 'text', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Recipient identity'),
('project_communications', 'message_type', 'text', 'NO', false, NULL, NULL, 'no_gleam_struct', '8-value enum, no Gleam type. BroadcastStatus is wrong type for this.'),
('project_communications', 'content', 'text', 'NO', false, NULL, NULL, 'no_gleam_struct', 'Message content'),
('project_communications', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Message metadata'),
('project_communications', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Creation time'),
('project_communications', 'read_at', 'timestamptz', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Read time'),
('project_communications', 'priority', 'text', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Priority level (text type, not integer)'),
('project_communications', 'git_hash', 'text', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Git context'),
('project_communications', 'git_branch', 'text', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Git context'),
('project_communications', 'environment', 'text', 'YES', false, NULL, NULL, 'no_gleam_struct', 'Environment context');

-- ============================================================================
-- projects: 14 DB columns, 13 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('projects', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('projects', 'name', 'text', 'NO', true, 'name', 'String', 'ok', NULL),
('projects', 'description', 'text', 'YES', true, 'description', 'Option(String)', 'ok', NULL),
('projects', 'path', 'text', 'NO', true, 'path', 'String', 'ok', NULL),
('projects', 'language', 'text', 'YES', true, 'language', 'Option(String)', 'ok', NULL),
('projects', 'framework', 'text', 'YES', true, 'framework', 'Option(String)', 'ok', NULL),
('projects', 'status', 'text', 'NO', true, 'status', 'ProjectStatus', 'ok', NULL),
('projects', 'git_remote', 'text', 'YES', true, 'git_remote', 'Option(String)', 'ok', NULL),
('projects', 'fingerprint', 'text', 'YES', true, 'fingerprint', 'Option(String)', 'ok', NULL),
('projects', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('projects', 'updated_at', 'timestamptz', 'YES', true, 'updated_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('projects', 'last_seen', 'timestamptz', 'YES', true, 'last_seen', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('projects', 'last_qc_at', 'timestamptz', 'YES', true, 'last_qc_at', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast'),
('projects', 'config', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Project configuration');

-- ============================================================================
-- memory: 13 DB columns, 7 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('memory', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('memory', 'content', 'text', 'NO', true, 'content', 'String', 'ok', NULL),
('memory', 'tags', 'ARRAY', 'YES', true, 'tags', 'List(String)', 'type_mismatch', 'PostgreSQL ARRAY decoded as List(String) - needs custom decoder'),
('memory', 'source', 'text', 'YES', true, 'source', 'String', 'ok', NULL),
('memory', 'agent_id', 'varchar', 'YES', true, 'agent_id', 'String', 'ok', NULL),
('memory', 'importance', 'integer', 'YES', true, 'importance', 'Int', 'ok', NULL),
('memory', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('memory', 'project_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Project ownership'),
('memory', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Memory metadata'),
('memory', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Update tracking'),
('memory', 'embedding', 'USER-DEFINED', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Vector embedding (pgvector)'),
('memory', 'session_id', 'varchar', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Session tracking'),
('memory', 'viewers', 'ARRAY', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Access control'),
('memory', 'has_sensitive', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Sensitive data flag');

-- ============================================================================
-- system_reviews: 22 DB columns, 20 Gleam fields
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('system_reviews', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String (query uses ::text cast)'),
('system_reviews', 'review_type', 'text', 'YES', true, 'review_type', 'Option(ReviewType)', 'ok', NULL),
('system_reviews', 'status', 'text', 'NO', true, 'status', 'ReviewStatus', 'ok', NULL),
('system_reviews', 'current_state', 'text', 'YES', true, 'current_state', 'Option(String)', 'ok', NULL),
('system_reviews', 'target_id', 'text', 'YES', true, 'target_id', 'Option(String)', 'ok', NULL),
('system_reviews', 'target_type', 'text', 'YES', true, 'target_type', 'Option(String)', 'ok', NULL),
('system_reviews', 'title', 'text', 'YES', true, 'title', 'Option(String)', 'ok', NULL),
('system_reviews', 'description', 'text', 'YES', true, 'description', 'Option(String)', 'ok', NULL),
('system_reviews', 'reviewer_id', 'text', 'YES', true, 'reviewer_id', 'Option(String)', 'ok', NULL),
('system_reviews', 'project_id', 'uuid', 'YES', true, 'project_id', 'Option(String)', 'type_mismatch', 'uuid as String (query uses ::text cast)'),
('system_reviews', 'methodology', 'text', 'YES', true, 'methodology', 'Option(ReviewMethodology)', 'ok', NULL),
('system_reviews', 'scope', 'text', 'YES', true, 'scope', 'Option(ReviewScope)', 'ok', NULL),
('system_reviews', 'follow_up_status', 'text', 'YES', true, 'follow_up_status', 'FollowUpStatus', 'ok', NULL),
('system_reviews', 'follow_up_due', 'timestamptz', 'YES', true, 'follow_up_due', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast (done in query)'),
('system_reviews', 'git_hash', 'text', 'YES', true, 'git_hash', 'Option(String)', 'ok', NULL),
('system_reviews', 'git_branch', 'text', 'YES', true, 'git_branch', 'Option(String)', 'ok', NULL),
('system_reviews', 'related_issue_id', 'uuid', 'YES', true, 'related_issue_id', 'Option(String)', 'type_mismatch', 'uuid as String (query uses ::text cast)'),
('system_reviews', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast (done in query)'),
('system_reviews', 'updated_at', 'timestamptz', 'YES', true, 'updated_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast (done in query)'),
('system_reviews', 'completed_at', 'timestamptz', 'YES', true, 'completed_at', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast (done in query)'),
('system_reviews', 'findings', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review findings (may be legacy, now in review_findings table)'),
('system_reviews', 'action_items', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Action items - unique data not stored elsewhere'),
('system_reviews', 'limitations', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Review limitations - unique data not stored elsewhere');

-- ============================================================================
-- review_findings: 15 DB columns, 16 Gleam fields (Gleam has resolved_at)
-- ============================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
('review_findings', 'id', 'uuid', 'NO', true, 'id', 'String', 'type_mismatch', 'uuid as String'),
('review_findings', 'review_id', 'uuid', 'NO', true, 'review_id', 'String', 'type_mismatch', 'uuid as String'),
('review_findings', 'finding_number', 'integer', 'NO', true, 'finding_number', 'Int', 'ok', NULL),
('review_findings', 'severity', 'text', 'NO', true, 'severity', 'FindingSeverity', 'ok', NULL),
('review_findings', 'category', 'text', 'NO', true, 'category', 'String', 'ok', NULL),
('review_findings', 'module', 'text', 'YES', true, 'module', 'Option(String)', 'ok', NULL),
('review_findings', 'title', 'text', 'NO', true, 'title', 'String', 'ok', NULL),
('review_findings', 'description', 'text', 'NO', true, 'description', 'String', 'ok', NULL),
('review_findings', 'evidence', 'text', 'YES', true, 'evidence', 'Option(String)', 'ok', NULL),
('review_findings', 'impact', 'text', 'YES', true, 'impact', 'Option(String)', 'ok', NULL),
('review_findings', 'status', 'text', 'NO', true, 'status', 'FindingStatus', 'ok', NULL),
('review_findings', 'related_issue_id', 'uuid', 'YES', true, 'related_issue_id', 'Option(String)', 'type_mismatch', 'uuid as String'),
('review_findings', 'created_at', 'timestamptz', 'NO', true, 'created_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('review_findings', 'updated_at', 'timestamptz', 'NO', true, 'updated_at', 'String', 'type_mismatch', 'timestamptz needs ::text cast'),
('review_findings', 'resolved_at', 'timestamptz', 'YES', true, 'resolved_at', 'Option(String)', 'type_mismatch', 'timestamptz needs ::text cast');
