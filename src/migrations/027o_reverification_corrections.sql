-- 027o_reverification_corrections.sql
-- Re-verification corrections: retract false positives, mark duplicates, correct severities
-- Based on systematic type alignment audit and code flow verification

-- ============================================================================
-- RETRACT: False positive findings (verified against node-postgres type mapping)
-- ============================================================================

-- #101: uuid doesn't need ::text (node-postgres returns uuid as string)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: node-postgres automatically returns uuid columns as JavaScript strings. No ::text cast is needed for uuid columns decoded with decode.string.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 101;

-- #109: areflect.fetch_recent_issues only SELECTs id,title,status,severity (no timestamps)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: The SELECT only includes id (uuid), title, status, severity. No timestamptz columns are selected. uuid is returned as string by node-postgres, so no ::text cast needed.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 109;

-- #117: tasks.project_id has default value
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: tasks.project_id has a default value of the psypi project UUID (0d324e68-b399-4b85-bd8a-6b1ef7b46168). The INSERT without project_id will use this default, which is correct.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 117;

-- #124: Gleam Bool compiles to JS boolean (no type mismatch)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: Gleam Bool compiles to JS boolean, so ctx.isIdle() returning JS true/false maps correctly to Gleam True/False. No type mismatch exists.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 124;

-- #158: Gleam within-package imports don't use package prefix
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: In Gleam, within the same package, modules are imported directly by name (import db, import task). The package name in gleam.toml is only used for external consumers. There is no namespace mismatch.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 158;

-- #162: All SQL uses parameterized queries (no injection risk)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: All SQL queries in psypi use parameterized queries ($1, $2, etc.) with dynamic.string/dynamic.int for values. No string interpolation in WHERE clauses was found.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 162;

-- #207: stats.gleam uses decode_bigint() which correctly handles bigint
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: stats.gleam uses decode_bigint() which correctly handles bigint via decode.string |> decode.map(int.parse). node-postgres returns bigint as JS string, so decode.string works without ::text cast.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 207;

-- #217: code_version returns raw dynamic.Dynamic (no decoder)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: code_version.gleam returns raw List(dynamic.Dynamic) rows without using Gleam decoders. The uuid/timestamptz type mismatch only affects Gleam decode.string, not raw dynamic values.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 217;

-- #218: get_code_versions() returns raw dynamic.Dynamic (no decoder)
UPDATE review_findings SET status = 'retracted',
  description = description || ' RETRACTED: get_code_versions() returns raw List(dynamic.Dynamic) rows without using Gleam decoders. The uuid/timestamptz type mismatch only affects Gleam decode.string, not raw dynamic values.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 218;

-- ============================================================================
-- DUPLICATE: Findings covered by more detailed type alignment audit findings
-- ============================================================================

-- #102: uuid+timestamptz → covered by #276 (timestamptz only, uuid retracted)
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE: The uuid part is retracted (node-postgres returns uuid as string). The timestamptz part is covered by #276.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 102;

-- #103: skill.get jsonb → covered by #278
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #278 which provides verified analysis with node-postgres type mapping evidence.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 103;

-- #118: auto_file_issue → covered by #279 and #280
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #279 (wrong column name "type" vs "issue_type") and #280 (missing project_id NOT NULL).'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 118;

-- #122: set_config/get_config → covered by #249
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #249 which provides verified analysis of the FFI type mismatch (JS null/string vs Gleam None/Some).'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 122;

-- #125: dual config stores → covered by #262
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #262 which provides the same analysis about FFI _configStore (in-memory) and psypi_config table (DB) never being synchronized.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 125;

-- #208: broadcast.stats COUNT(*) → covered by #283
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #283 which provides verified analysis with node-postgres type mapping evidence.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 208;

-- #209: is_s_still_idle COUNT(*) → covered by #282
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #282 which provides verified root cause (bigint type mismatch, not missing ::text).'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 209;

-- #215: record_tool_error → covered by #279 and #280
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #279 (wrong column name) and #280 (missing project_id).'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 215;

-- #221: inter_review uuid+timestamptz → covered by #284
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE: The uuid part is retracted (node-postgres returns uuid as string). The timestamptz part is covered by #284.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 221;

-- #227: TaskStatus missing FAKE_COMPLETE → covered by #287
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #287 which provides verified analysis with DB CHECK constraint evidence.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 227;

-- #229: IssueStatus mismatch → covered by #210
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #210 which provides verified analysis with DB CHECK constraint evidence.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 229;

-- #254: migration tracking → covered by #270
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #270 which provides the same analysis with more detail.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 254;

-- #266: Error(_) -> Ok(default) → covered by #159
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #159. Actual count is 3 instances, not 8: system_review_db.gleam:438, issue_db.gleam:251, a_db_reader.gleam:44.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 266;

-- #164: no type audit → covered by #286
UPDATE review_findings SET status = 'duplicate',
  description = description || ' DUPLICATE of #286 which provides the completed type alignment audit with verified findings.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 164;

-- ============================================================================
-- SEVERITY CORRECTIONS
-- ============================================================================

-- #272: node_ffi.execute() is dead code (no Gleam module imports it)
UPDATE review_findings SET severity = 'low',
  description = description || ' UPDATE: node_ffi.execute() is dead code — no Gleam module imports it. The security risk is latent but not currently exploitable.'
WHERE review_id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837' AND finding_number = 272;

-- ============================================================================
-- DESCRIPTION CORRECTIONS
-- ============================================================================

-- #146: Corrected from "UNION ALL mismatched columns" to "memory has no saved_at column"
-- (already done in psql, this is for migration tracking)

-- #159: Corrected count from "4+" to 3 instances
-- (already done in psql, this is for migration tracking)

-- #244: Corrected root cause from "missing ::text" to "bigint type mismatch"
-- (already done in psql, this is for migration tracking)
