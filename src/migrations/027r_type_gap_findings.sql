-- 027r_type_gap_findings.sql
-- New findings from comprehensive type_inventory audit

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 298, 'high', 'type_gap', 'task.gleam',
  'TaskStatus missing FakeComplete - DB allows FAKE_COMPLETE but Gleam has no variant',
  'tasks.status CHECK allows PENDING/RUNNING/COMPLETED/FAILED/FAKE_COMPLETE. Gleam TaskStatus only has Pending/Running/Completed/Failed. string_to_status will Error on FAKE_COMPLETE rows.',
  'task.gleam:9-14 defines TaskStatus without FakeComplete. DB constraint: tasks_status_check.',
  'Any task with FAKE_COMPLETE status causes decode failure. Tasks marked FAKE_COMPLETE are invisible to Gleam.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 299, 'high', 'type_gap', 'project.gleam',
  'projects.status uses UPPERCASE in DB but Gleam string_to_status expects lowercase',
  'DB CHECK: ACTIVE/INACTIVE/ARCHIVED. Gleam ProjectStatus: Active/Inactive/Archived maps to lowercase. If Gleam writes lowercase active, INSERT fails. If DB returns UPPERCASE ACTIVE, string_to_status fails.',
  'project.gleam string_to_status. DB constraint: projects_status_check.',
  'Either read or write of project status fails depending on case handling.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 300, 'high', 'type_gap', 'broadcast.gleam',
  'BroadcastStatus type is for a phantom column - project_communications has no status column',
  'Gleam defines BroadcastStatus(Pending/Sent/Failed/Cancelled) and Broadcast struct has status field. But project_communications table has no status column. list()/get_recent() hardcode sent as status. stats() references status and will fail at runtime.',
  'broadcast.gleam:15-20 defines BroadcastStatus. broadcast.gleam:258 stats() references status column. DB schema: project_communications has 13 columns, none named status.',
  'stats() always fails at runtime. BroadcastStatus is meaningless without a DB column. message_type (8 values) has no Gleam type at all.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 301, 'medium', 'type_gap', 'inter_review.gleam',
  'inter_reviews has 3 enum columns (status/response_status/reviewer_type) with no Gleam types',
  'inter_reviews.status: pending/in_progress/completed/failed/superseded (5 values). response_status: pending/accepted/rejected/partial/superseded (5 values). reviewer_type: ai/human (2 values). inter_review.gleam has no enum types for any of these.',
  'inter_review.gleam reads status as raw string. DB constraints: inter_reviews_status_check, inter_reviews_response_status_check, inter_reviews_reviewer_type_check.',
  'No compile-time safety for inter_review status values. Superseded/partial values are invisible to Gleam logic.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 302, 'medium', 'type_gap', 'agent_identity.gleam',
  'agent_souls has 5 implicit enum columns (trigger_type/drive_mode/activation/id_prefix/role) with no Gleam types',
  'trigger_type: event/prompt. drive_mode: reactive/autonomous. id_prefix: A/S. role: SomaticBot/AutonomicBot. activation: complex rules. All used as raw strings in Gleam. No CHECK constraints in DB.',
  'agent_identity.gleam:120 reads trigger_type, drive_mode, activation. seed.gleam:42 inserts them. a_db_reader.gleam:64 reads role.',
  'No type safety for agent identity fields. Typos in trigger_type/drive_mode values cause silent failures.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 303, 'medium', 'type_gap', 'task.gleam',
  'tasks has 3 enum columns (category/type/error_category) with no Gleam types - 22 values total',
  'tasks.category: security/performance/feature/bugfix (4+NULL). tasks.type: analysis/implementation/documentation/bugfix/research/testing/deployment/maintenance/discussion/announcement (10). tasks.error_category: NETWORK/AUTH/TIMEOUT/SERVER/TRANSPORT/LOGIC/RESOURCE/UNKNOWN (8+NULL). All used as raw strings.',
  'task.gleam has TaskStatus but no TaskCategory/TaskType/TaskErrorCategory. DB constraints: tasks_category_check, tasks_type_check, tasks_error_category_check.',
  'No compile-time safety for task categorization. error_category UPPER case inconsistent with other lowercase enums.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 304, 'low', 'type_gap', 'meeting.gleam',
  'meeting_opinions.position (support/oppose/neutral) has no Gleam type',
  '3 DB values. Used as raw string in opinion_decoder. No type safety for meeting opinion positions.',
  'meeting.gleam:277 reads meeting_opinions. DB constraint: meeting_opinions_position_check.',
  'Low impact - opinions are read-only display data. But no compile-time safety.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 305, 'medium', 'type_gap', 'event_hooks.gleam',
  'psypi_event_hooks.hook_status (active/inactive/error/experimental) has no Gleam type',
  '4 DB values. event_hooks.gleam reads hook_status as raw string. No type safety for hook lifecycle.',
  'event_hooks.gleam:87 reads hook_status. DB constraint: psypi_event_hooks_hook_status_check.',
  'Cannot pattern match on hook status. Error/experimental hooks not handled differently in Gleam.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 306, 'low', 'type_gap', 'multiple',
  'system_directives.priority (critical/high/medium/low) has no Gleam type',
  '4 DB values. Same values as FindingSeverity but semantically different. Could reuse FindingSeverity or create DirectivePriority.',
  'DB constraint: system_directives_priority_check.',
  'Low impact - directives not heavily used. But semantic confusion if reused.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 307, 'high', 'type_gap', 'a_db_reader.gleam',
  'agent_sessions.status is alive/dead/sleeping but Gleam code assumes alive/idle - no type, wrong values',
  'DB CHECK: alive/dead/sleeping. a_db_reader.gleam:33 queries status=alive AND last_heartbeat > NOW()-5min. No Gleam type for AgentSessionStatus. The sleeping status is never handled. is_s_still_idle() assumes idle but DB has sleeping.',
  'a_db_reader.gleam:33. DB constraint: agent_sessions_status_check with alive/dead/sleeping.',
  'is_s_still_idle() logic is based on wrong assumptions about status values. sleeping agents are not detected. No type means no compile-time checking.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 308, 'low', 'type_gap', 'skill.gleam',
  'skill_audit_log.action (9 values) has no Gleam type - audit trail invisible to Gleam',
  'installed/uninstalled/approved/rejected/enabled/disabled/updated/reviewed/used. skill.gleam has no audit type. Table not queried by Gleam code.',
  'DB constraint: skill_audit_log_action_check.',
  'Low impact - audit log not used by Gleam. But if needed, no type exists.');

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 309, 'high', 'type_gap', 'type_inventory',
  'Type inventory: 51 enum columns total, only 10 match Gleam types. 18 psypi-used columns have gaps.',
  'mismatch: 2 (issues.status, meetings.status). missing_variant: 3 (issues.type, skills.source, tasks.status). wrong_type: 1 (project_communications.message_type). case_mismatch: 1 (projects.status). phantom_column: 1 (BroadcastStatus). no_gleam_type: 18 psypi-used + 15 non-psypi. ok: 10.',
  'type_inventory table in database. Query: SELECT * FROM type_inventory_summary;',
  'Root cause of many bugs. Without correct types, decoders fail silently, INSERTs violate constraints, and pattern matching is impossible. All type gaps must be resolved before fixing individual issues.');
