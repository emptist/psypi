-- 029c_medium_findings_verification.sql
-- Verify all medium-severity findings against reality

-- ============================================================
-- DUPLICATE FINDINGS — mark as duplicate
-- ============================================================
-- a_db_reader COUNT(*) decode.int duplicates (same as #414)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 282;

-- a_db_reader "closed" status duplicates (same as #22)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 295;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 343;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 376;

-- semantic_id is_idle duplicates (same as #10/#250)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 140;

-- broadcast.send empty project_id duplicates (same as #6)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 120;

-- inter_reviews struct gap duplicates (same as #411)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 235;

-- heartbeat duplicates (same as #3/#289)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 289;

-- memory.save omits project_id duplicates (same as #7)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 293;

-- learning omit project_id duplicates (same as #8)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 294;

-- TaskStatus missing FakeComplete duplicates (already retracted at #298)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 14;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 32;

-- SkillSource missing AiBuilt duplicates (already retracted at #316)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 15;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 33;

-- MeetingStatus Pending duplicates (already retracted at #16)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 34;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 228;

-- IssueStatus mismatch duplicates (already retracted at #13)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 31;

-- IssueType missing proposal duplicates (already retracted at #230)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 230;

-- inter_reviews type_gap duplicates (same as #395)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 301;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 335;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 358;

-- agent_souls type_gap duplicates (same as #394)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 302;
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 327;

-- tasks type_gap duplicates (same as #397)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 303;

-- agent_sessions status type_gap duplicates (same as #307)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 328;

-- stats no project_id filter duplicates (same as #384)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 384;

-- areflect save_issue project_id duplicates (same as #2)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 338;

-- areflect save_task project_id (same root cause as #2)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 339;

-- config desync duplicates (same as #28)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 7;

-- tasks.project_id Option(String) duplicates (same as #311)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 311;

-- missing ::text cast duplicates (same as #17)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (104, 275);

-- monitor_ai UPPER_CASE duplicates (same as #381/#382)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 387;

-- Gleam code UPPER_CASE duplicates (same as #385)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 387;

-- ============================================================
-- RETRACTED FINDINGS — verified as incorrect
-- ============================================================
-- #13: IssueStatus mismatch — FALSE, all 6 variants match DB CHECK
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 13;

-- #16: MeetingStatus has Pending — FALSE, Pending removed, now Active/Completed/Cancelled matches DB
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 16;

-- #141: hook_on_tool_result synchronous return — FALSE, Pi hooks can be synchronous
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 141;

-- #149: Dynamic imports in every hook — FALSE, generated JS uses static import statements
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 149;

-- #151: Audit trigger source=learn — FALSE, no audit trigger on learning_insights
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 151;

-- #160: idle_since reset on every tool call — FALSE, only reset when ctx_is_idle is False
UPDATE review_findings SET status = 'retracted' WHERE finding_number = 160;

-- ============================================================
-- DOWNGRADED FINDINGS
-- ============================================================
-- #156: call_monitor retry without backoff — only retries once, low impact
UPDATE review_findings SET severity = 'low', status = 'confirmed' WHERE finding_number = 156;

-- ============================================================
-- CONFIRMED MEDIUM FINDINGS
-- ============================================================
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 22;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 119;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 134;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 136;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 147;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 154;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 245;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 246;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 248;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 252;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 267;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 269;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 271;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 305;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 313;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 317;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 318;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 326;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 330;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 331;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 334;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 341;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 347;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 396;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 398;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 399;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 400;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 401;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 404;
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 405;

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
SELECT 'MEDIUM FINDINGS VERIFICATION SUMMARY' AS section;
SELECT status, COUNT(*) AS cnt FROM review_findings WHERE severity = 'medium' GROUP BY status ORDER BY cnt DESC;
