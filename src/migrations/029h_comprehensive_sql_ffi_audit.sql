-- 029h_comprehensive_sql_ffi_audit.sql
-- Comprehensive audit of SQL case mismatches and FFI type mismatches
-- Cross-referenced against actual DB CHECK constraints

-- ============================================================
-- FINDING #417: monitor_ai.gleam:357 uses 'PENDING' for skills.status
-- ============================================================
-- skills_status_check allows: pending/approved/rejected/blocked/installed/uninstalled (lowercase)
-- monitor_ai.gleam:357 uses WHERE status = 'PENDING' (uppercase) — will never match
-- This is a DIFFERENT bug from #382 (inter_reviews.status = 'FAILED')
-- Both are in monitor_ai.gleam but on different tables
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  417, 'high', 'logic_error', 'monitor_ai',
  'monitor_ai.gleam:357 uses uppercase PENDING for skills.status — DB uses lowercase pending',
  'monitor_ai.gleam:357 queries skills table with WHERE status = ''PENDING'' but skills_status_check constraint only allows lowercase values (pending/approved/rejected/blocked/installed/uninstalled). The uppercase PENDING will never match any rows, so stale_skills_count will always be 0 regardless of actual pending skills. This is a different bug from #382 (inter_reviews.status = FAILED).',
  'monitor_ai.gleam:357: FROM skills WHERE status = ''PENDING''. psql: skills_status_check = CHECK ((status = ANY (ARRAY[''pending''::text, ''approved''::text, ''rejected''::text, ''blocked''::text, ''installed''::text, ''uninstalled''::text])))',
  'confirmed'
);

-- ============================================================
-- FINDING #418: Duplicate semantic_id() function in agent_identity_types.gleam and agent_identity.gleam
-- ============================================================
-- agent_identity_types.gleam:22 defines pub fn semantic_id(ctx) -> Result(String, IdentityError)
-- agent_identity.gleam:62 defines fn semantic_id(ctx) -> Result(String, IdentityError)
-- Both have identical logic but different error constructors:
--   agent_identity_types uses MissingSessionId
--   agent_identity uses NotFound("missing model id")
-- get_enriched_identity() in agent_identity.gleam calls its LOCAL semantic_id()
-- agent_identity_types.semantic_id() is called by resolved_identity() and agent_id()
-- If semantic_id logic changes, both must be updated — code duplication risk
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  418, 'medium', 'code_duplication', 'agent_identity',
  'semantic_id() is duplicated in agent_identity.gleam and agent_identity_types.gleam with different error types',
  'semantic_id() is defined in both agent_identity_types.gleam:22 (public) and agent_identity.gleam:62 (private). The logic is identical but the error constructors differ: agent_identity_types uses MissingSessionId while agent_identity uses NotFound("missing model id"). get_enriched_identity() calls the local copy, while resolved_identity() and agent_id() call the types copy. If the ID format changes, both must be updated independently. The agent_identity.gleam import does NOT import semantic_id from agent_identity_types.',
  'agent_identity_types.gleam:22 pub fn semantic_id; agent_identity.gleam:62 fn semantic_id; agent_identity.gleam:4 imports only types, not semantic_id',
  'confirmed'
);

-- ============================================================
-- FINDING #419: get_config FFI returns null instead of undefined — breaks Option(String) contract
-- ============================================================
-- pi_extension_ffi.mjs:153: return _configStore[key] || null
-- Gleam type: pub fn get_config(key: String) -> option.Option(String)
-- In Gleam JS FFI, Option(String) expects: string (Some) or undefined (None)
-- Returning null is NOT the same as undefined — Gleam will treat null as Some(null)
-- This causes phantom Some values in hook_on_agent_end.gleam:34-60
-- Every call to get_config("idle_since") when key is not set returns a phantom Some
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  419, 'critical', 'ffi_type_mismatch', 'pi_extension_ffi',
  'get_config FFI returns null instead of undefined — breaks Gleam Option(String) contract',
  'pi_extension_ffi.mjs:153 returns _configStore[key] || null when key is not found. Gleam Option(String) in JS FFI expects undefined for None, not null. Returning null causes Gleam to treat it as Some(null) — a phantom value. This affects hook_on_agent_end.gleam:34 which calls get_config("idle_since") and pattern-matches on Some/None. The Some branch will always match even when no config is set, causing incorrect idle-since tracking. Fix: return undefined instead of null.',
  'pi_extension_ffi.mjs:153: return _configStore[key] || null; pi_extension.gleam:67: pub fn get_config(key: String) -> option.Option(String); hook_on_agent_end.gleam:34: case get_config("idle_since")',
  'confirmed'
);

-- ============================================================
-- CASE CONVENTION REFERENCE TABLE
-- ============================================================
-- Documented for future reference — which tables use which case
-- UPPERCASE status: tasks, projects
-- lowercase status: skills, inter_reviews, issues, meetings, system_reviews, event_hooks, agent_sessions
-- No status constraint: provider_api_keys, project_communications

-- Verify the case convention reference
SELECT 'CASE CONVENTION REFERENCE' AS section;
SELECT 
  conrelid::regclass::text AS table_name,
  conname AS constraint_name,
  CASE WHEN pg_get_constraintdef(oid) LIKE '%''A-Z%' OR pg_get_constraintdef(oid) LIKE '%PENDING%''%' OR pg_get_constraintdef(oid) LIKE '%ACTIVE%''%' 
    THEN 'UPPERCASE' 
    ELSE 'lowercase' 
  END AS case_convention,
  pg_get_constraintdef(oid) AS constraint_def
FROM pg_constraint 
WHERE contype = 'c' 
  AND pg_get_constraintdef(oid) LIKE '%status%'
  AND pg_get_constraintdef(oid) LIKE '%= ANY%'
ORDER BY 1;

SELECT '=== CONFIRMED FINDINGS BY SEVERITY ===' AS section;
SELECT severity, COUNT(*) AS cnt
FROM review_findings
WHERE status = 'confirmed'
GROUP BY severity
ORDER BY severity;
