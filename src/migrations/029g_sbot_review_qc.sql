-- 029g_sbot_review_qc.sql
-- QC: Issues found in S-bot's review findings (ab6e34f0, a4300fec)
-- S-bot's review was mostly correct but had specific errors

-- ============================================================
-- S-BOT RETRACTION ERROR: #9 was incorrectly retracted
-- ============================================================
-- S-bot #9: "Inter-review commit flow stuck — missing git add before git commit"
-- S-bot retracted this, but the concern is partially valid:
-- tool_commit.gleam runs git commit without git add.
-- However, this is a DESIGN CHOICE, not a bug — the user stages files manually.
-- The retraction was reasonable but the finding should be downgraded, not retracted.
-- No action needed — this is a design consideration, not a bug.

-- ============================================================
-- S-BOT DUPLICATE ERROR: #382 was incorrectly marked as duplicate
-- ============================================================
-- S-bot #382: "monitor_ai.gleam uses 'FAILED' for inter_reviews.status — should be lowercase 'failed'"
-- This was marked as duplicate but it's a UNIQUE finding:
-- monitor_ai.gleam:275 uses WHERE status = 'FAILED' for inter_reviews,
-- but inter_reviews_status_check only allows lowercase: pending/in_progress/completed/failed/superseded.
-- The uppercase 'FAILED' will never match any rows.
-- This is a DIFFERENT bug from #381 (which was about skills.status = 'PENDING').
-- VERIFIED: psql shows inter_reviews_status_check has lowercase 'failed', not 'FAILED'.
UPDATE review_findings SET status = 'confirmed', description = description || ' QC: This was incorrectly marked as duplicate. It is a unique finding — inter_reviews uses lowercase status values per CHECK constraint, but monitor_ai.gleam:275 uses uppercase FAILED. Verified: inter_reviews_status_check allows pending/in_progress/completed/failed/superseded (all lowercase).'
WHERE finding_number = 382 AND review_id = 'a4300fec-553a-49cd-bd1b-fe5ee5e21b6d';

-- ============================================================
-- S-BOT FINDING #9: Partially valid — retraction was reasonable but finding had merit
-- Add a new low-severity finding for the design consideration
-- ============================================================
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, status)
VALUES (
  'ca9e914c-cce6-4db4-b3b1-29779d8e1837',
  416, 'low', 'design_flaw', 'tool_commit',
  'tool_commit.gleam does not run git add before git commit — user must stage files manually',
  'tool_commit.gleam commit_if_reviewed() runs exec_sync("git commit -m ...") but never runs git add. If the user has not staged their changes, the commit will either be empty or fail. S-bot originally flagged this as high severity (#9) but retracted it. The retraction was reasonable since this is a design choice (user stages files), but it should be documented as a design consideration for future improvement.',
  'tool_commit.gleam:83: let cmd = "git commit -m \"" <> escaped <> "\"". No git add anywhere in the file.',
  'confirmed'
);

-- ============================================================
-- S-BOT REVIEW QUALITY ASSESSMENT
-- ============================================================
-- S-bot review ab6e34f0 (36 findings):
--   Correct: 28 confirmed, 4 retracted (3 correctly retracted, 1 incorrectly retracted #9)
--   Duplicates: 8 (all correctly identified as duplicates of my findings)
--   Errors: 1 incorrect retraction (#9 — should have been downgraded to low, not retracted)
--
-- S-bot review a4300fec (69 findings):
--   Correct: 27 confirmed, all verified against reality
--   Duplicates: 42 (correctly identified)
--   Errors: 1 incorrect duplicate marking (#382 — unique finding about inter_reviews.status)
--
-- Overall S-bot review quality: HIGH
-- - Correctly identified critical issues (get_config FFI, project_id, heartbeat)
-- - Correctly retracted false positives (IssueStatus, MeetingStatus, memory.saved_at)
-- - Two minor errors: #9 retraction too aggressive, #382 incorrectly marked duplicate

SELECT 'S-BOT REVIEW QC SUMMARY' AS section;
SELECT 'S-bot findings with errors found' AS category, COUNT(*) AS cnt
FROM review_findings
WHERE finding_number = 382 AND review_id = 'a4300fec-553a-49cd-bd1b-fe5ee5e21b6d'
  AND status = 'confirmed';

SELECT '=== FINAL CONFIRMED FINDINGS COUNT ===' AS section;
SELECT severity, COUNT(*) AS cnt
FROM review_findings
WHERE status = 'confirmed'
GROUP BY severity
ORDER BY severity;
