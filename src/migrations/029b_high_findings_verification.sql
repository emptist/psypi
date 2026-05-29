-- 029b_high_findings_verification.sql
-- Verify all high-severity findings against reality

-- ============================================================
-- DUPLICATE FINDINGS — mark as duplicate
-- ============================================================
-- broadcast.stats() duplicates (same as #355/#356 critical)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 6;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 35;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 139;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 283;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 290;

-- seed.gleam multi-statement duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 18;

-- areflect.save_issue project_id duplicates (same as #2 critical)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 30;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 116;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 281;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 288;

-- inter_review timestamptz duplicates (same as #5/#284/#413)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 29;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 100;

-- config desync duplicates (same as #28)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 262;

-- a_orchestrator never writes inter-review duplicates (same as #264)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 247;

-- inter_reviews struct gap duplicates (same as #411)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 312;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 342;

-- BroadcastStatus phantom type duplicates (same as #402)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 300;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 324;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 357;

-- code_version missing params duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 129;

-- memory.save() decoder duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 138;

-- agent_identity missing params duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 256;

-- project_id raw String duplicates (same as #1)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 291;

-- missing ::text cast duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 17;

-- monitor_ai auto_file_issue duplicates (same as #375)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 279;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 280;

-- memory.gleam search SELECT * duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 349;

-- task.gleam result jsonb duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 310;

-- get_config FFI duplicates (same as #26/#412)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 261;

-- tool_commit missing git add duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 258;

-- ============================================================
-- RETRACTED FINDINGS — verified as incorrect
-- ============================================================
-- #9: meeting decoder reads timestamptz without ::text — FALSE, all queries use ::text
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 9;

-- #11: already says RETRACTED in title but status was open
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 11;

-- #292: meeting decoder timestamptz — FALSE, all meeting queries use ::text
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 292;

-- #298: TaskStatus missing FakeComplete — FALSE, FakeComplete exists at task.gleam:14
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 298;

-- #316: SkillSource missing AiBuilt — FALSE, AiBuilt exists at skill.gleam:14
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 316;

-- #346: stats.gleam decode_bigint uses decode.string — this is CORRECT for bigint
-- node-postgres returns bigint as JS string, decode.string is the right decoder
UPDATE review_findings SET status = 'retracted', description = 'RETRACTED: node-postgres returns bigint (int8) as JS string. decode.string is the correct decoder for bigint. stats.gleam decode_bigint() is actually correct.' WHERE finding_number = 346;

-- ============================================================
-- DOWNGRADED FINDINGS
-- ============================================================
-- #7: memory.save omits project_id — memory.project_id is nullable, INSERT succeeds
UPDATE review_findings SET severity = 'medium', status = 'confirmed' WHERE finding_number = 7;

-- #8: learning omit project_id — learning_insights.project_id is nullable
UPDATE review_findings SET severity = 'medium', status = 'confirmed' WHERE finding_number = 8;

-- #344: monitor_ai completed_at may not be populated — COALESCE handles NULL
UPDATE review_findings SET severity = 'low', status = 'confirmed' WHERE finding_number = 344;

-- #123: unwrapGleamResult may not handle all shapes — low impact
UPDATE review_findings SET severity = 'medium', status = 'confirmed' WHERE finding_number = 123;

-- ============================================================
-- CONFIRMED HIGH FINDINGS
-- ============================================================
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 10;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 12;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 19;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 20;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 27;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 28;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 137;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 146;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 250;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 251;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 265;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 274;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 276;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 278;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 284;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 307;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 309;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 337;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 380;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 381;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 385;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 386;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 390;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 391;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 393;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 394;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 395;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 397;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 407;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 409;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 411;

-- ============================================================
-- NEW FINDING: a_db_reader.gleam COUNT(*) decode.int fails on bigint
-- ============================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  (SELECT id FROM system_reviews WHERE review_type = 'system' ORDER BY created_at DESC LIMIT 1),
  414, 'high', 'type_mismatch', 'a_db_reader',
  'a_db_reader.gleam: COUNT(*) returns bigint but decode.int expects JS number — decode always fails',
  'a_db_reader.gleam:56 uses decode.field("cnt", decode.int) for COUNT(*) result. PostgreSQL COUNT(*) returns bigint (int8). node-postgres returns int8 as JS string, not number. decode.int expects JS number and fails on string. The error handler returns Ok(True), so is_s_still_idle() always returns True regardless of actual session state. This is a bigint type mismatch, not a missing ::text issue.',
  'a_db_reader.gleam:33: SELECT COUNT(*) as cnt FROM agent_sessions. a_db_reader.gleam:56: decode.field("cnt", decode.int). node-postgres int8→string. decode.int expects number. Error handler returns Ok(True).',
  'confirmed'
);

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
SELECT 'HIGH FINDINGS VERIFICATION SUMMARY' AS section;
SELECT status, COUNT(*) AS cnt FROM review_findings WHERE severity = 'high' GROUP BY status ORDER BY cnt DESC;
