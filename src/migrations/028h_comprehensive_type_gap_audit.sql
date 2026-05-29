-- 028h_comprehensive_type_gap_audit.sql
-- Comprehensive audit of all type gaps between PostgreSQL and Gleam
-- Cross-referenced with actual Gleam source code

-- Finding #393: 32 columns with no_gleam_type — systematic type safety gap
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  393, 'high', 'type_gap', 'schema',
  '32 database enum columns have no Gleam type — all handled as raw String',
  'The type_inventory table shows 32 columns with gap_status=no_gleam_type across 16 tables used by psypi. These columns have CHECK constraints or implicit enum values in PostgreSQL but are decoded as String in Gleam, losing type safety. Any typo in string values goes undetected at compile time and causes silent runtime failures. Categories: (1) agent identity: agent_type, status, role, id_prefix, trigger_type, drive_mode, activation (7 columns). (2) task metadata: category, error_category, type (3 columns). (3) inter-review: status, response_status, reviewer_type (3 columns). (4) event hooks: event_name, hook_status (2 columns). (5) skills: review_status, scan_status (2 columns). (6) other: memory.source, meeting_opinions.position, notifications.priority, provider_api_keys.status, psypi_config.key, learning_insights.insight_type, agent_prefixes.prefix, agent_prefixes.name, code_versions.id, code_versions.saved_at (10 columns). Plus 1 wrong_type (project_communications.message_type vs BroadcastStatus), 1 phantom_column (project_communications.status), 2 range_constraints.',
  'type_inventory query: SELECT gap_status, COUNT(*) FROM type_inventory WHERE used_by_psypi=true GROUP BY gap_status. Results: no_gap=10, no_gleam_type=32, ok=16, phantom_column=1, range_constraint=2, wrong_type=1. Verified by grep for "pub type" in src/*.gleam: 83 type definitions found, but only 16 map to DB enum columns.',
  'open'
);

-- Finding #394: agent_identity fields are all String — 7 enum columns with no type safety
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  394, 'high', 'type_gap', 'agent_identity',
  'agent_identity.gleam EnrichedIdentity has 7 String fields that should be enum types',
  'EnrichedIdentity has: role: String, trigger_type: String, drive_mode: String, activation: String, prefix: String, source: String, thinking_level: String. Of these, role (AutonomicBot/SomaticBot), trigger_type (event/prompt), drive_mode (autonomous/reactive), activation (3 complex values), and prefix (A/S/G) all come from database columns with implicit or explicit enum values. Without Gleam types, any string mismatch causes silent failures. For example, if trigger_type value changes in DB, Gleam code using hardcoded "event" or "prompt" strings would silently fail to match.',
  'agent_identity.gleam:19-32: EnrichedIdentity struct with 7 String fields. agent_souls table: id_prefix(text, values A/S), role(text, values AutonomicBot/SomaticBot), trigger_type(text, values event/prompt), drive_mode(text, values autonomous/reactive), activation(text, 3 complex values). fetch_soul_by_prefix() decodes all as decode.string.',
  'open'
);

-- Finding #395: inter_review.gleam Review.status is String — should be InterReviewStatus enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  395, 'high', 'type_gap', 'inter_review',
  'inter_review.gleam Review.status is String — DB has CHECK with 5 values, no InterReviewStatus enum',
  'The inter_reviews table has status CHECK constraint: pending/in_progress/completed/failed/superseded. But inter_review.gleam:51 defines Review with status: String. list_reviews() takes status as Option(String) with no validation. This means any typo in status filter (e.g. "pendign" instead of "pending") silently returns empty results instead of a compile error. Additionally, response_status (pending/accepted/rejected/partial/superseded) and reviewer_type (ai/human) also lack Gleam types.',
  'inter_review.gleam:47-55: Review struct with status: String. DB: inter_reviews.status CHECK ((status = ANY (ARRAY[''pending'', ''in_progress'', ''completed'', ''failed'', ''superseded'']))). Also: inter_reviews.response_status CHECK with 5 values, inter_reviews.reviewer_type CHECK with 2 values.',
  'open'
);

-- Finding #396: event_hooks.gleam has 2 String enum fields — event_name and hook_status
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  396, 'medium', 'type_gap', 'event_hooks',
  'event_hooks.gleam EventHook has event_name: String and hook_status: String — both are enums',
  'EventHook struct has event_name: String (8 implicit values: on_agent_start, on_before_agent_start, on_agent_end, on_tool_call, on_tool_result, on_session_start, on_session_end, on_user_prompt) and hook_status: String (4 CHECK values: active/inactive/error/experimental). format_hooks_summary() and set_hook_status() use hardcoded strings. No EventName or HookStatus enum. Typo in event name causes hook to never trigger without any error.',
  'event_hooks.gleam:23-34: EventHook with event_name: String, hook_status: String. psypi_event_hooks.event_name has 8 distinct values. psypi_event_hooks.hook_status CHECK ((status = ANY (ARRAY[''active'', ''inactive'', ''error'', ''experimental'']))).',
  'open'
);

-- Finding #397: tasks table has 3 enum columns with no Gleam types
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  397, 'high', 'type_gap', 'task',
  'tasks table: category, error_category, type columns have no Gleam enum types',
  'The tasks table has 3 enum columns without Gleam types: (1) tasks.category with values security/performance/feature/bugfix (nullable). (2) tasks.error_category with UPPER_CASE values NETWORK/AUTH/TIMEOUT/SERVER/TRANSPORT/LOGIC/RESOURCE/UNKNOWN (nullable, will be migrated to lowercase). (3) tasks.type with 10 values: analysis/implementation/documentation/bugfix/research/testing/deployment/maintenance/discussion/announcement. TaskStatus exists but TaskCategory, TaskErrorCategory, and TaskType do not. These are used as raw strings in SQL queries and decoded as String.',
  'task.gleam: TaskStatus enum exists (Pending/Running/Completed/Failed/FakeComplete). But no TaskCategory, TaskErrorCategory, or TaskType. tasks table: category text CHECK, error_category text CHECK, type text CHECK with 10 values. DB functions like get_failure_recommendations() and create_issue_from_dlq() reference error_category values as strings.',
  'open'
);

-- Finding #398: meeting_opinions.position column missing from Gleam Opinion struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  398, 'medium', 'type_gap', 'meeting',
  'meeting_opinions.position column (support/oppose/neutral) missing from Gleam Opinion struct',
  'The meeting_opinions table has a position column (text, values: support/oppose/neutral) but the Gleam Opinion struct at meeting.gleam:27-34 only has: id, meeting_id, author, perspective, reasoning, created_at. The position field is completely missing from the Gleam type, meaning meeting opinions lose their stance information when decoded. No MeetingPosition enum exists either.',
  'meeting.gleam:27-34: Opinion(id: String, meeting_id: String, author: String, perspective: String, reasoning: Option(String), created_at: String). DB: meeting_opinions has position column (text) with values support/oppose/neutral. Column exists in table but not in Gleam struct.',
  'open'
);

-- Finding #399: agents.gleam Agent.agent_type is String — should be AgentType enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  399, 'medium', 'type_gap', 'agents',
  'agents.gleam Agent.agent_type is String — DB has implicit enum autonomic/somatic',
  'The Agent struct has agent_type: String but agent_sessions.agent_type has implicit enum values autonomic/somatic. Without an AgentType enum, any code filtering by agent type uses raw string comparison with no compile-time safety. Similarly, agent_sessions.status (alive/dead/sleeping) has no AgentSessionStatus enum.',
  'agents.gleam:8-11: Agent(id: String, agent_type: String, created_at: String). DB: agent_sessions.agent_type varchar(50) with values autonomic/somatic. agent_sessions.status CHECK ((status = ANY (ARRAY[''alive'', ''dead'', ''sleeping'']))).',
  'open'
);

-- Finding #400: monitor.gleam Notification.priority is String — should be NotificationPriority enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  400, 'medium', 'type_gap', 'monitor',
  'monitor.gleam Notification.priority is String — DB has implicit enum critical/high/medium/low',
  'The Notification struct has priority: String but notifications.priority defaults to medium with implicit values critical/high/medium/low. create_notification() takes priority as String param with no validation. monitor.gleam:190-237 uses CASE WHEN for priority sorting. Without a NotificationPriority enum, invalid priority values can be inserted into the database.',
  'monitor.gleam:144-152: Notification struct with priority: String. monitor.gleam:229: create_notification(agent_id: String, priority: String, ...). DB: notifications.priority text DEFAULT ''medium''. Implicit values: critical/high/medium/low.',
  'open'
);

-- Finding #400: psypi_config.key is String — should be ConfigKey phantom type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  401, 'medium', 'type_gap', 'psypi_config',
  'psypi_config.key is String — should be ConfigKey phantom type for compile-time safety',
  'psypi_config.gleam:26 reads config by key string: get(key: String). The key column has implicit enum values (monitor_debounce_ms, last_wakeup, etc.). Without a ConfigKey type, a typo in the key name causes a silent NotFound error instead of a compile-time error. This is exactly the kind of bug that Gleam types are designed to prevent.',
  'psypi_config.gleam:26: pub fn get(key: String) -> promise.Promise(Result(String, ConfigError)). DB: psypi_config.key text with implicit enum values. Typo in key name causes silent runtime failure.',
  'open'
);

-- Finding #402: BroadcastStatus is a phantom type — maps to non-existent status column
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  402, 'critical', 'type_gap', 'broadcast',
  'BroadcastStatus type maps to non-existent status column — should map to message_type instead',
  'broadcast.gleam defines BroadcastStatus with 4 variants (Pending/Sent/Failed/Cancelled) but project_communications has no status column. The actual column is message_type with 8 values: task/review/feedback/status/question/answer/notification/broadcast. BroadcastStatus does not match any column. This phantom type causes: (1) stats() SQL error referencing non-existent status column, (2) list()/get_recent() hardcode "sent" as status which does not exist, (3) the type gives false sense of type safety while actually being disconnected from the database schema.',
  'broadcast.gleam:16-21: BroadcastStatus(Pending/Sent/Failed/Cancelled). DB: project_communications has message_type column (8 values) but NO status column. Verified: psql returns ERROR: column "status" does not exist when querying project_communications.status.',
  'open'
);

-- Finding #403: skills.review_status and scan_status have no Gleam types and are never read
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  403, 'low', 'type_gap', 'skill',
  'skills.review_status (6 values) and scan_status (5 values) have no Gleam types and are never read by psypi',
  'The skills table has review_status (pending/auto_passed/auto_failed/needs_manual_review/manually_approved/manually_rejected) and scan_status (pending/clean/suspicious/malicious/reviewed) columns with CHECK constraints but no Gleam types. These columns are never read by any psypi Gleam code. If they are intended for future use, types should be defined. If not, they represent dead schema.',
  'type_inventory: skills.review_status gap_status=no_gleam_type, skills.scan_status gap_status=no_gleam_type. Grep for review_status/scan_status in src/*.gleam: no matches found.',
  'open'
);

-- Finding #404: memory.source has 3 implicit values but no MemorySource enum
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  404, 'medium', 'type_gap', 'memory',
  'memory.source has 3 implicit values (learn/areflect/traenupi) but no MemorySource enum',
  'The memory table source column has 3 values in data: learn, areflect, traenupi. learning.gleam:28 hardcodes "learn" as source value. Without a MemorySource enum, any new source value or typo goes undetected. The Memory struct has source: String at memory.gleam:14.',
  'memory.gleam:14: Memory struct with source: String. learning.gleam:28: hardcodes source="learn". DB: SELECT DISTINCT source FROM memory returns learn/areflect/traenupi.',
  'open'
);

-- Finding #405: provider_api_keys.status has no ApiKeyStatus enum — monitor hardcodes strings
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  405, 'medium', 'type_gap', 'monitor',
  'provider_api_keys.status (in_use/not_used) has no ApiKeyStatus enum — monitor hardcodes strings',
  'monitor.gleam:104 sets status to "not_used" and :113 sets "in_use" as raw strings. The DB has a unique index WHERE status = ''in_use'' to enforce single active key. Without an ApiKeyStatus enum, a typo like "in-use" or "inuse" would bypass the unique index constraint and allow multiple active keys.',
  'monitor.gleam:104: status = ''not_used''. monitor.gleam:113: status = ''in_use''. DB: provider_api_keys.status text. Unique index: CREATE UNIQUE INDEX ... WHERE status = ''in_use''.',
  'open'
);

-- Finding #406: learning_insights.insight_type has no InsightType enum — areflect hardcodes "pattern"
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  406, 'low', 'type_gap', 'areflect',
  'learning_insights.insight_type has 2 values (pattern/architecture) but no InsightType enum',
  'learning_insights.insight_type has 2 values in data: pattern and architecture. areflect.gleam:186 hardcodes "pattern" as insight_type. Without an InsightType enum, the "architecture" value is never used from Gleam code, and any new insight type would require finding all hardcoded strings.',
  'areflect.gleam:186: hardcodes insight_type = ''pattern''. DB: SELECT DISTINCT insight_type FROM learning_insights returns pattern/architecture.',
  'open'
);
