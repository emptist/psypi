-- 027y_missing_struct_field_inventory.sql
-- Add struct_field_inventory entries for 10 tables used in Gleam but not yet audited
-- These tables: agent_jobs, agent_souls, agent_sessions, psypi_config,
--   activity_log, provider_api_keys, notifications, learning_insights,
--   agent_identities, code_versions

-- =====================================================================
-- agent_jobs (8 DB columns, Gleam reads 3: job, priority, category)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('agent_jobs', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK not read by Gleam. JOIN key only.'),
  ('agent_jobs', 'soul_id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'FK to agent_souls. Used in JOIN but not selected.'),
  ('agent_jobs', 'job', 'text', 'NO', true, 'job', 'String', 'ok', NULL),
  ('agent_jobs', 'priority', 'integer', 'NO', true, 'priority', 'Int', 'ok', NULL),
  ('agent_jobs', 'category', 'text', 'YES', true, 'category', 'String', 'enum_gap', '13-value implicit enum, no Gleam type'),
  ('agent_jobs', 'is_active', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE is_active = true but not selected'),
  ('agent_jobs', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam'),
  ('agent_jobs', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam');

-- =====================================================================
-- agent_souls (13 DB columns, Gleam reads 7-8 depending on query)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('agent_souls', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Used in JOIN but not selected directly.'),
  ('agent_souls', 'id_prefix', 'text', 'NO', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE id_prefix = $1 but not selected. Implicit enum A/S/G.'),
  ('agent_souls', 'name', 'text', 'NO', true, 'name', 'String', 'ok', NULL),
  ('agent_souls', 'role', 'text', 'NO', true, 'role', 'String', 'enum_gap', 'Implicit enum AutonomicBot/SomaticBot'),
  ('agent_souls', 'domain', 'text', 'NO', true, 'domain', 'String', 'ok', NULL),
  ('agent_souls', 'responsibility', 'text', 'NO', true, 'responsibility', 'String', 'ok', NULL),
  ('agent_souls', 'trigger_type', 'text', 'NO', true, 'trigger_type', 'String', 'enum_gap', 'Implicit enum event/prompt'),
  ('agent_souls', 'drive_mode', 'text', 'NO', true, 'drive_mode', 'String', 'enum_gap', 'Implicit enum autonomous/reactive'),
  ('agent_souls', 'activation', 'text', 'NO', true, 'activation', 'String', 'enum_gap', '3 complex values with spaces'),
  ('agent_souls', 'content', 'text', 'NO', true, 'content', 'String', 'ok', 'Read by s_db_reader.gleam:21'),
  ('agent_souls', 'is_active', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE is_active = true but not selected'),
  ('agent_souls', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam'),
  ('agent_souls', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam');

-- =====================================================================
-- agent_sessions (11 DB columns, Gleam reads 1: COUNT(*))
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('agent_sessions', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Not read by Gleam.'),
  ('agent_sessions', 'identity_id', 'varchar(100)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'FK to agent_identities. Not read.'),
  ('agent_sessions', 'agent_type', 'varchar(50)', 'NO', false, NULL, NULL, 'missing_from_gleam', 'Implicit enum. Not read by Gleam.'),
  ('agent_sessions', 'process_id', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('agent_sessions', 'working_on', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'FK to tasks. Not read.'),
  ('agent_sessions', 'status', 'varchar(20)', 'YES', false, NULL, NULL, 'enum_gap', 'CHECK(alive/dead/sleeping). Used in WHERE only.'),
  ('agent_sessions', 'started_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('agent_sessions', 'last_heartbeat', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE > NOW() - INTERVAL only.'),
  ('agent_sessions', 'ended_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('agent_sessions', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('agent_sessions', 'last_heartbeat_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Duplicate of last_heartbeat? Not read.');

-- =====================================================================
-- psypi_config (6 DB columns, Gleam reads 2: key, value)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('psypi_config', 'key', 'text', 'NO', true, 'key', 'String', 'enum_gap', 'Implicit enum. Used in WHERE key = $1.'),
  ('psypi_config', 'value', 'text', 'NO', true, 'value', 'String', 'ok', NULL),
  ('psypi_config', 'encrypted', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam. Security feature ignored.'),
  ('psypi_config', 'description', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('psypi_config', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('psypi_config', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.');

-- =====================================================================
-- activity_log (8 DB columns, Gleam reads 0 directly — only COUNT(*))
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('activity_log', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Not read.'),
  ('activity_log', 'agent_id', 'text', 'NO', true, 'agent_id', 'String', 'ok', 'Used in INSERT param'),
  ('activity_log', 'activity', 'text', 'NO', true, 'activity', 'String', 'enum_gap', '39-value implicit enum. Used in INSERT.'),
  ('activity_log', 'context', 'jsonb', 'YES', true, 'context', 'String', 'type_mismatch', 'DB is jsonb, Gleam passes as String. JSON string passed directly.'),
  ('activity_log', 'git_hash', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not used by Gleam.'),
  ('activity_log', 'git_branch', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not used by Gleam.'),
  ('activity_log', 'environment', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Defaults to development. Not set by Gleam INSERT.'),
  ('activity_log', 'timestamp', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE > NOW() - INTERVAL only.');

-- =====================================================================
-- provider_api_keys (10 DB columns, Gleam reads 2-3: provider, model, status)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('provider_api_keys', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Not read.'),
  ('provider_api_keys', 'provider', 'text', 'NO', true, 'provider', 'String', 'ok', NULL),
  ('provider_api_keys', 'encrypted_key', 'text', 'NO', false, NULL, NULL, 'ok', 'Correctly not exposed to Gleam.'),
  ('provider_api_keys', 'encrypted_iv', 'text', 'NO', false, NULL, NULL, 'ok', 'Correctly not exposed to Gleam.'),
  ('provider_api_keys', 'encrypted_tag', 'text', 'NO', false, NULL, NULL, 'ok', 'Correctly not exposed to Gleam.'),
  ('provider_api_keys', 'encrypted_salt', 'text', 'NO', false, NULL, NULL, 'ok', 'Correctly not exposed to Gleam.'),
  ('provider_api_keys', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('provider_api_keys', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('provider_api_keys', 'status', 'text', 'NO', true, 'status', 'String', 'enum_gap', 'Implicit enum in_use/not_used. Set via UPDATE.'),
  ('provider_api_keys', 'model', 'text', 'YES', true, 'model', 'Option(String)', 'ok', NULL);

-- =====================================================================
-- notifications (7 DB columns, Gleam reads all 7)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('notifications', 'id', 'uuid', 'NO', true, 'id', 'String', 'ok', 'node-postgres returns uuid as string'),
  ('notifications', 'agent_id', 'text', 'NO', true, 'agent_id', 'String', 'ok', NULL),
  ('notifications', 'priority', 'text', 'NO', true, 'priority', 'String', 'enum_gap', 'Implicit enum critical/high/medium/low. No CHECK constraint.'),
  ('notifications', 'title', 'text', 'NO', true, 'title', 'String', 'ok', NULL),
  ('notifications', 'body', 'text', 'NO', true, 'body', 'String', 'ok', NULL),
  ('notifications', 'created_at', 'timestamp', 'YES', true, 'created_at', 'String', 'type_mismatch', 'DB is timestamp without tz. Gleam reads as String with ::text cast.'),
  ('notifications', 'read_at', 'timestamp', 'YES', true, 'read_at', 'Option(String)', 'type_mismatch', 'DB is timestamp without tz. Gleam reads as Option(String) with ::text cast.');

-- =====================================================================
-- learning_insights (13 DB columns, Gleam writes 4: insight_type, title, content, confidence)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('learning_insights', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Auto-generated. Not read.'),
  ('learning_insights', 'project_id', 'uuid', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect.gleam INSERT. Creates orphan insights.'),
  ('learning_insights', 'insight_type', 'varchar(50)', 'NO', true, 'insight_type', 'String', 'enum_gap', 'Implicit enum pattern/architecture. Hardcoded as pattern.'),
  ('learning_insights', 'title', 'varchar(255)', 'NO', true, 'title', 'String', 'ok', NULL),
  ('learning_insights', 'content', 'text', 'NO', true, 'content', 'String', 'ok', NULL),
  ('learning_insights', 'evidence', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect. Defaults to [].'),
  ('learning_insights', 'priority', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect. Defaults to 5.'),
  ('learning_insights', 'confidence', 'double precision', 'YES', true, 'confidence', 'Float', 'ok', 'Hardcoded as 0.8 in areflect.'),
  ('learning_insights', 'is_applied', 'boolean', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect. Defaults to false.'),
  ('learning_insights', 'applied_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect.'),
  ('learning_insights', 'expires_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect.'),
  ('learning_insights', 'metadata', 'jsonb', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not set by areflect. Defaults to {}.'),
  ('learning_insights', 'created_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Auto-generated. Not read.');

-- =====================================================================
-- agent_identities (14 DB columns, Gleam reads 3: id, agent_type, created_at)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('agent_identities', 'id', 'varchar(100)', 'NO', true, 'id', 'String', 'ok', NULL),
  ('agent_identities', 'project', 'varchar(255)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam.'),
  ('agent_identities', 'git_hash', 'varchar(100)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam.'),
  ('agent_identities', 'machine_fingerprint', 'varchar(64)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam.'),
  ('agent_identities', 'created_at', 'timestamptz', 'YES', true, 'created_at', 'String', 'ok', 'Read with ::text cast'),
  ('agent_identities', 'updated_at', 'timestamptz', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('agent_identities', 'display_name', 'varchar(255)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'description', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'owner', 'varchar(255)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam.'),
  ('agent_identities', 'source', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'session_id', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'agent_type', 'varchar(50)', 'YES', true, 'agent_type', 'String', 'enum_gap', 'Implicit enum self/autonomic/somatic. Defaults to self.'),
  ('agent_identities', 'model', 'varchar(255)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'thinking_level', 'varchar(20)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. In AgentIdentity type.'),
  ('agent_identities', 'id_prefix', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by agents.gleam. Implicit enum A/S/G.');

-- =====================================================================
-- code_versions (11 DB columns, Gleam reads 2: file_path, saved_at)
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('code_versions', 'id', 'uuid', 'NO', false, NULL, NULL, 'missing_from_gleam', 'PK. Not read.'),
  ('code_versions', 'file_path', 'text', 'NO', true, 'content', 'String', 'name_mismatch', 'DB column file_path mapped to content field in context_row_decoder. Confusing naming.'),
  ('code_versions', 'content', 'text', 'NO', false, NULL, NULL, 'missing_from_gleam', 'File content not read by monitor_ai.gleam.'),
  ('code_versions', 'version_hash', 'varchar(64)', 'NO', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('code_versions', 'saved_by', 'varchar(255)', 'NO', false, NULL, NULL, 'missing_from_gleam', 'Used in WHERE saved_by = $1 but not selected.'),
  ('code_versions', 'saved_at', 'timestamptz', 'YES', true, 'saved_at', 'String', 'ok', 'Read with ::text cast in UNION ALL query.'),
  ('code_versions', 'commit_hash', 'varchar(255)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('code_versions', 'reason', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('code_versions', 'project_name', 'varchar(100)', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Defaults to psypi. Not read.'),
  ('code_versions', 'file_size', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.'),
  ('code_versions', 'line_count', 'integer', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read.');
