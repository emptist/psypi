-- 029a_critical_findings_verification.sql
-- Verify all 19 critical findings against reality
-- Status values: open/confirmed/disputed/fixed/wont_fix/duplicate/retracted

-- DUPLICATE FINDINGS
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 322;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 323;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 345;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 121;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 249;

-- #1: "No Project type" — PARTIALLY FALSE. Project type EXISTS but project_id is raw String
UPDATE review_findings
SET title = 'project_id is raw String everywhere — no type-safe ProjectId wrapper',
    severity = 'high',
    description = 'Project type exists (project.gleam:22) but project_id is used as raw String across 14 locations. No ProjectId opaque type to prevent mixing with other uuid strings.',
    evidence = 'Verified: project.gleam:22 defines pub type Project. grep for project_id.*String shows 14 raw String usages. No opaque type ProjectId exists.',
    status = 'confirmed'
WHERE finding_number = 1;

-- #2: areflect.save_issue omits project_id — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 2;

-- #3: No code updates agent_sessions.last_heartbeat — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 3;

-- #4: A-bot wakeup chain 4 sequential failures — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 4;

-- #5: inter_review queries fail on timestamptz — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 5;

-- #24: OVERALL ASSESSMENT — CONFIRMED (summary)
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 24;

-- #25: A-bot wakeup chain broken — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 25;

-- #26: get_config FFI returns raw JS values — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 26;

-- #355: broadcast.stats() status column — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 355;

-- #356: broadcast.stats() priority >= 2 — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 356;

-- #375: monitor_ai uses 'type' instead of 'issue_type' — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 375;

-- #389: Migration order constraint — CONFIRMED but downgrade to medium (strategy, not code bug)
UPDATE review_findings
SET severity = 'medium',
    status = 'confirmed'
WHERE finding_number = 389;

-- #402: BroadcastStatus phantom type — CONFIRMED
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 402;

-- NEW #412: get_config FFI breaks hook_on_agent_end debounce
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  412, 'critical', 'ffi_mismatch', 'hook_on_agent_end',
  'get_config FFI breaks debounce: hook_on_agent_end.gleam case get_config() never matches Some/None',
  'hook_on_agent_end.gleam:60 calls get_config("monitor_debounce_ms") and pattern-matches on option.Some/option.None. But get_config FFI returns JS null or JS string, not Gleam Some/None constructors. Compiled JS: if (get_config("monitor_debounce_ms") instanceof $option.Some) — always false because JS string is not instanceof Some class. Impact: debounce logic completely non-functional. idle_since check on line 79 has same FFI bug.',
  'hook_on_agent_end.gleam:60: case get_config("monitor_debounce_ms"). build/dev/javascript/psypi/hook_on_agent_end.mjs:97: if ($3 instanceof $option.Some). pi_extension_ffi.mjs:153: return _configStore[key] || null. gleam_stdlib/option.mjs: Some extends CustomType.',
  'confirmed'
);

-- NEW #413: inter_review.gleam requested_at timestamptz decode failure
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  413, 'critical', 'missing_cast', 'inter_review',
  'inter_review.gleam: requested_at timestamptz decoded as String — node-postgres returns Date object',
  'inter_review.gleam:117 uses decode.field("requested_at", decode.string) but requested_at is timestamptz. node-postgres parses timestamptz into JS Date objects, not strings. decode.string expects JS string and fails on Date objects. Every inter_review query returning requested_at will fail to decode. Unlike other modules (task.gleam, project.gleam, meeting.gleam) which use ::text cast in SQL, inter_review.gleam has no ::text cast for requested_at.',
  'inter_review.gleam:117: decode.field("requested_at", decode.string). inter_review.gleam:148: SELECT requested_at FROM inter_reviews — no ::text cast. DB: requested_at is timestamptz. All other modules use created_at::text pattern.',
  'confirmed'
);

SELECT 'CRITICAL FINDINGS VERIFICATION SUMMARY' AS section;
SELECT finding_number, LEFT(title, 70) AS title, severity, status
FROM review_findings WHERE severity = 'critical' ORDER BY finding_number;
