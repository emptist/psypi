-- 027z_latest_codebase_audit_findings.sql
-- Findings from latest codebase audit (2026-05-29)
-- Covers: monitor_ai.gleam type column bug, stats.gleam bigint decoder,
--         psypi_event_hooks missing from type_inventory, memory.gleam timestamptz,
--         meeting.gleam Pending fix verification, updated type_inventory corrections

-- =====================================================================
-- #345: monitor_ai.gleam INSERT uses 'type' column — should be 'issue_type'
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 345, 'critical', 'sql_error', 'monitor_ai.gleam',
  'monitor_ai.gleam auto_file_error() uses column ''type'' but issues table has ''issue_type'' — INSERT always fails',
  'monitor_ai.gleam:561 SQL: INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment). The issues table has no ''type'' column — the column is named ''issue_type''. This INSERT always fails with: ERROR: column "type" does not exist. Verified: SELECT column_name FROM information_schema.columns WHERE table_name=''issues'' AND column_name IN (''type'',''issue_type'') returns only issue_type.',
  'monitor_ai.gleam:561 SQL with ''type''. issue_db.gleam:88 correctly uses ''issue_type''. DB: issues table has issue_type column, not type.',
  'Tool error auto-filing is completely broken. Every call to auto_file_error() fails silently (error is caught and ignored). Monitor AI cannot create issues for tool errors.'
);

-- =====================================================================
-- #346: stats.gleam decode_bigint() uses decode.string for COUNT(*)
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 346, 'high', 'type_mismatch', 'stats.gleam',
  'stats.gleam decode_bigint() uses decode.string but COUNT(*) returns number from node-postgres — decoder fails',
  'stats.gleam:45-50 decode_bigint() uses decode.string to decode COUNT(*) result. PostgreSQL COUNT(*) returns bigint. node-postgres parses int8 (bigint) as JavaScript number for values within safe integer range. decode.string fails on a number value. The stats() function always returns QueryError("Failed to decode stats"). monitor_ai.gleam correctly uses COUNT(*)::INT and decode.int.',
  'stats.gleam:45 decode.string in decode_bigint(). stats.gleam:16-19 SQL: (SELECT COUNT(*) FROM tasks) as tasks — no ::text or ::INT cast. a_db_reader.gleam:33 uses COUNT(*) as cnt with decode.int. monitor_ai.gleam:63 uses COUNT(*)::INT.',
  'psypi-stats-show tool always fails. No project statistics can be displayed. The fix is to either: (1) use COUNT(*)::text and keep decode.string, (2) use COUNT(*)::INT and decode.int like monitor_ai.gleam, or (3) use decode.int directly since node-postgres returns small counts as numbers.'
);

-- =====================================================================
-- #347: psypi_event_hooks table missing from type_inventory
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 347, 'medium', 'type_gap', 'event_hooks.gleam',
  'psypi_event_hooks table missing from type_inventory — hook_status has CHECK enum with no Gleam type',
  'psypi_event_hooks has CHECK constraint on hook_status: active, inactive, error, experimental. event_hooks.gleam reads hook_status as String and uses hardcoded strings in format_hooks_summary() and set_hook_status(). No HookStatus enum. The table was missing from type_inventory entirely.',
  'event_hooks.gleam:91 CASE WHEN hook_status = ''active''. event_hooks.gleam:233 set_hook_status(event_name, status: String). DB: psypi_event_hooks_hook_status_check CHECK (active/inactive/error/experimental). type_inventory: no row for psypi_event_hooks.',
  'No type safety for hook status. set_hook_status() accepts any string. Typos like "actve" would succeed in the UPDATE but the row would fail the CHECK constraint, causing a confusing error.'
);

-- =====================================================================
-- #348: event_hooks.gleam reads worker_action as agentbot_action — column alias mismatch
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 348, 'medium', 'name_mismatch', 'event_hooks.gleam',
  'event_hooks.gleam reads agentbot_action column but DB has worker_action — column alias masks the real column',
  'event_hooks.gleam:88 SQL: COALESCE(agentbot_action, '''') as agentbot_action. The psypi_event_hooks table has both worker_action and agentbot_action columns. The SQL reads agentbot_action directly. But the DB schema shows worker_action was the original column and agentbot_action was added later. Both exist. The EventHook type has agentbot_action field. The worker_action column is never read by Gleam.',
  'event_hooks.gleam:88 SQL reads agentbot_action. DB: psypi_event_hooks has both worker_action and agentbot_action columns. worker_action is never referenced in Gleam.',
  'worker_action column is dead data from Gleam perspective. If other projects write to worker_action, those values are invisible to psypi. The relationship between worker_action and agentbot_action is unclear.'
);

-- =====================================================================
-- #349: memory.gleam search() uses SELECT * — timestamptz columns decoded as String fail
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 349, 'high', 'type_mismatch', 'memory.gleam',
  'memory.gleam search() uses SELECT * — timestamptz columns returned as Date objects, decode.string fails',
  'memory.gleam:101 SQL: SELECT * FROM memory. The memory table has created_at and updated_at as timestamptz. node-postgres returns timestamptz as JavaScript Date objects. The memory_decoder() uses decode.field("created_at", decode.string) which fails on Date objects. The search() function always returns empty results because all decode.run calls fail silently.',
  'memory.gleam:101 SELECT * FROM memory. memory.gleam:43 decode.field("created_at", decode.string). DB: memory.created_at is timestamptz. node-postgres returns timestamptz as Date object.',
  'Memory search is completely broken. Every row decode fails silently. The list comprehension catches decode errors and returns empty list. Fix: use created_at::text in SQL or add ::text cast.'
);

-- =====================================================================
-- #350: memory.gleam save() passes tags as string-formatted PG array — fragile
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 350, 'medium', 'data_quality', 'memory.gleam',
  'memory.gleam save() passes text[] tags as string-formatted PG array — fragile for special characters',
  'memory.gleam:63 dynamic.string(format_pg_array(tags)). format_pg_array() produces {tag1,tag2} format. This works for simple tags but breaks for tags containing commas, braces, or quotes. PostgreSQL expects proper array format with escaping for special characters. The correct approach is to use node-postgres array parameter binding.',
  'memory.gleam:30-33 format_pg_array(). memory.gleam:63 dynamic.string(format_pg_array(tags)). DB: memory.tags is _text (text array).',
  'Tags with special characters (commas, braces, quotes, NULL) will be incorrectly parsed. A tag like "hello,world" would be split into two tags. A tag with a brace would produce malformed array literal.'
);

-- =====================================================================
-- #351: memory.gleam Memory type missing project_id, metadata, session_id, viewers, has_sensitive
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 351, 'medium', 'struct_gap', 'memory.gleam',
  'Memory type has 7 fields but DB table has 14 columns — 7 columns inaccessible from Gleam',
  'memory table has 14 columns: id, project_id, content, source, tags, metadata, created_at, updated_at, embedding, importance, agent_id, session_id, viewers, has_sensitive. Memory type has: id, content, tags, source, agent_id, importance, created_at. Missing: project_id, metadata, updated_at, embedding, session_id, viewers, has_sensitive. The search() function uses SELECT * which returns all 14 columns but the decoder only handles 7.',
  'memory.gleam:14-22 Memory type with 7 fields. DB: memory table has 14 columns. memory.gleam:101 SELECT * FROM memory returns all columns.',
  'project_id is not set on INSERT creating orphan memories. has_sensitive flag is never checked — sensitive data could be stored without protection. session_id is not set — cannot trace memories to sessions. viewers is not used — access control on memories is not enforced.'
);

-- =====================================================================
-- #352: Verified fix — meeting.gleam Pending variant removed
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 352, 'info', 'fix_verified', 'meeting.gleam',
  'VERIFIED: MeetingStatus.Pending phantom variant has been removed — now matches DB CHECK constraint',
  'meeting.gleam now defines MeetingStatus with 3 variants: Active, Completed, Cancelled. string_to_status() no longer maps "pending". This matches the DB CHECK constraint: CHECK (status IN (''active'',''completed'',''cancelled'')). Finding #325 can be marked as resolved.',
  'meeting.gleam:7-9 MeetingStatus type. meeting.gleam:44-48 string_to_status. DB: meetings_status_check CHECK (active/completed/cancelled).',
  'Fix verified. MeetingStatus now correctly maps to DB constraint. No phantom variants.'
);

-- =====================================================================
-- #353: Verified fix — issue_types.gleam now matches DB CHECK constraints
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 353, 'info', 'fix_verified', 'issue_types.gleam',
  'VERIFIED: IssueStatus and IssueType now match DB CHECK constraints exactly',
  'issue_types.gleam now defines IssueStatus with 6 variants (Open, Acknowledged, InProgress, Resolved, WontFix, Duplicate) matching DB CHECK: open, acknowledged, in_progress, resolved, wont_fix, duplicate. IssueType now has 7 variants including Proposal matching DB CHECK: bug, inconsistency, feature, improvement, question, debt, proposal. Previous mismatch (Closed vs WontFix/Duplicate) is fixed.',
  'issue_types.gleam:12-18 IssueStatus. issue_types.gleam:20-27 IssueType. DB: issues_status_check, issues_issue_type_check.',
  'Fix verified. IssueStatus and IssueType now correctly map to DB constraints.'
);

-- =====================================================================
-- #354: Verified fix — skill.gleam SkillSource now includes AiBuilt
-- =====================================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837', 354, 'info', 'fix_verified', 'skill.gleam',
  'VERIFIED: SkillSource now includes AiBuilt matching DB CHECK constraint',
  'skill.gleam now defines SkillSource with 5 variants: Clawhub, Local, Generated, Imported, AiBuilt. string_to_source maps "ai-built" -> AiBuilt. This matches DB CHECK: source IN (''clawhub'',''local'',''generated'',''imported'',''ai-built'').',
  'skill.gleam:9-15 SkillSource. skill.gleam:49-55 string_to_source. DB: skills_source_check.',
  'Fix verified. SkillSource now correctly maps to DB constraint.'
);

-- =====================================================================
-- Add psypi_event_hooks to type_inventory
-- =====================================================================
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES
  ('psypi_event_hooks', 'hook_status',
    ARRAY['active','inactive','error','experimental'],
    NULL, NULL,
    'no_gleam_type',
    'psypi_event_hooks.hook_status has CHECK constraint with 4 values. event_hooks.gleam reads as String and uses hardcoded strings in format_hooks_summary() and set_hook_status(). No HookStatus enum.',
    true),
  ('psypi_event_hooks', 'event_name',
    ARRAY['on_agent_start','on_before_agent_start','on_agent_end','on_tool_call','on_tool_result','on_session_start','on_session_end','on_user_prompt'],
    NULL, NULL,
    'no_gleam_type',
    'psypi_event_hooks.event_name has 8 distinct values used as implicit enum. event_hooks.gleam:record_trigger() takes event_name as String param. No EventName enum.',
    true);

-- =====================================================================
-- Update type_inventory for verified fixes
-- =====================================================================
UPDATE type_inventory SET gap_status = 'ok', gleam_type_name = 'MeetingStatus', gleam_variants = ARRAY['Active','Completed','Cancelled'], gap_detail = NULL
WHERE table_name = 'meetings' AND column_name = 'status';

UPDATE type_inventory SET gap_status = 'ok', gleam_type_name = 'IssueStatus', gleam_variants = ARRAY['Open','Acknowledged','InProgress','Resolved','WontFix','Duplicate'], gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'status';

UPDATE type_inventory SET gap_status = 'ok', gleam_type_name = 'IssueType', gleam_variants = ARRAY['Bug','Inconsistency','Feature','Improvement','Question','Debt','Proposal'], gap_detail = NULL
WHERE table_name = 'issues' AND column_name = 'issue_type';

UPDATE type_inventory SET gap_status = 'ok', gleam_type_name = 'SkillSource', gleam_variants = ARRAY['Clawhub','Local','Generated','Imported','AiBuilt'], gap_detail = NULL
WHERE table_name = 'skills' AND column_name = 'source';

-- =====================================================================
-- Mark finding #325 as resolved (MeetingStatus.Pending fix)
-- =====================================================================
UPDATE review_findings SET status = 'resolved', resolution = 'MeetingStatus.Pending phantom variant removed in working tree. meeting.gleam now matches DB CHECK constraint exactly.'
WHERE finding_number = 325 AND review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';

-- =====================================================================
-- Add struct_field_inventory for psypi_event_hooks
-- =====================================================================
INSERT INTO struct_field_inventory (table_name, db_column_name, db_data_type, db_nullable, in_gleam_struct, gleam_field_name, gleam_field_type, gap_type, gap_detail) VALUES
  ('psypi_event_hooks', 'id', 'uuid', 'NO', true, 'id', 'String', 'ok', 'Read with ::text cast'),
  ('psypi_event_hooks', 'event_name', 'text', 'NO', true, 'event_name', 'String', 'enum_gap', '8-value implicit enum. No EventName type.'),
  ('psypi_event_hooks', 'hook_status', 'text', 'YES', true, 'hook_status', 'String', 'enum_gap', 'CHECK(active/inactive/error/experimental). No HookStatus type.'),
  ('psypi_event_hooks', 'monitor_action', 'text', 'NO', true, 'monitor_action', 'String', 'ok', NULL),
  ('psypi_event_hooks', 'worker_action', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam. Superseded by agentbot_action?'),
  ('psypi_event_hooks', 'injection_enabled', 'boolean', 'YES', true, 'injection_enabled', 'Bool', 'ok', NULL),
  ('psypi_event_hooks', 'description', 'text', 'YES', true, 'description', 'String', 'ok', 'Read via COALESCE(description, '''')'),
  ('psypi_event_hooks', 'last_triggered', 'timestamp', 'YES', true, 'last_triggered', 'String', 'ok', 'Read with ::text cast via COALESCE'),
  ('psypi_event_hooks', 'trigger_count', 'integer', 'YES', true, 'trigger_count', 'Int', 'ok', NULL),
  ('psypi_event_hooks', 'error_count', 'integer', 'YES', true, 'error_count', 'Int', 'ok', NULL),
  ('psypi_event_hooks', 'last_error', 'text', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam. Written by record_error().'),
  ('psypi_event_hooks', 'created_at', 'timestamp', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('psypi_event_hooks', 'updated_at', 'timestamp', 'YES', false, NULL, NULL, 'missing_from_gleam', 'Not read by Gleam.'),
  ('psypi_event_hooks', 'agentbot_action', 'text', 'YES', true, 'agentbot_action', 'String', 'ok', 'Read via COALESCE(agentbot_action, '''')');

-- =====================================================================
-- Summary update
-- =====================================================================
UPDATE system_reviews 
SET status = 'in_progress',
    description = description || E'\n\nPhase 6 (2026-05-29): Latest codebase audit. Found 3 CRITICAL SQL errors (#345 monitor_ai type column, #346 stats decode_bigint, #349 memory SELECT * timestamptz). Added psypi_event_hooks to type_inventory (2 entries). Verified 3 fixes: MeetingStatus.Pending removed, IssueStatus/IssueType aligned, SkillSource.AiBuilt added. Added struct_field_inventory for psypi_event_hooks (14 rows). Total: 56 type_inventory entries, 354 findings.'
WHERE id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';
