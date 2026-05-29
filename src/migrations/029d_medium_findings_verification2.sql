-- 029d_medium_findings_verification2.sql
-- Verify remaining medium-severity findings against reality

-- ============================================================
-- DUPLICATE FINDINGS
-- ============================================================
-- missing ::text cast duplicates (same as #17)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (105, 106, 107, 108, 110);

-- missing_type duplicates (same as #393)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (360, 361, 363, 366, 369, 370);

-- unused_columns duplicates (same as #407)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (232, 233, 234, 238, 240);

-- no connection pool duplicates (same as #23/#137)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 253;

-- type_coverage duplicates (same as #393)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (36, 296, 297);

-- struct_gap duplicates (same as #407/#409)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (314, 315, 351, 408, 410);

-- structural_gap duplicates (same as #407)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 321;

-- wrong_status duplicates
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 206;

-- type_alignment duplicates (same as #17)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 286;

-- data_migration duplicates (same as #388)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 388;

-- sql_error duplicates (same as #382)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 382;

-- areflect schema mismatch duplicates (same as #285)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 285;

-- ============================================================
-- RETRACTED FINDINGS
-- ============================================================
-- #115: IssueStatus mismatch — FALSE, all 6 variants match DB CHECK
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 115;

-- #210: IssueStatus missing acknowledged/wont_fix/duplicate — FALSE, all exist
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 210;

-- #348: event_hooks column name mismatch — FALSE, agentbot_action exists in DB
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 348;

-- ============================================================
-- CONFIRMED MEDIUM FINDINGS
-- ============================================================
-- Error handling anti-patterns
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 21;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 159;

-- Performance
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 23;

-- Config desync
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 126;

-- Disconnected systems
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 127;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 128;

-- Missing params
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 132;

-- Hardcoded config
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 135;

-- Error handling
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 142;

-- Dead code
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 145;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 255;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 260;

-- FFI mismatch
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 153;

-- Security
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 155;

-- Design
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 270;

-- Data quality
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 350;

-- Missing field
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 377;

-- Case-sensitive status
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 113;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 114;

-- Unused table
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 231;

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
SELECT 'MEDIUM FINDINGS VERIFICATION 2 SUMMARY' AS section;
SELECT status, COUNT(*) AS cnt FROM review_findings WHERE severity = 'medium' GROUP BY status ORDER BY cnt DESC;
