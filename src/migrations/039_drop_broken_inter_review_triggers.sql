-- Migration 039: Drop two broken triggers on inter_reviews
-- Date: 2026-06-02
-- Reason: Both triggers reference schema/columns that don't exist or violate NOT NULL
-- constraints, causing every inter_reviews INSERT to fail. See
-- docs/DEEP-ANALYSIS-A-BOT-NOT-WORKING-2026-06-02.md (RC-2, RC-3).
--
-- The triggers were nice-to-have automations:
--   - broadcast_review_finding: posts a finding to a "broadcasts" channel/table
--   - link_review_to_issue_auto: creates an issue when overall_score < 50
-- Both have been broken since before this audit. We drop them rather than
-- re-implement them (avoid-the-hard-tasks strategy). S can still create issues
-- and broadcasts via its own tools when it sees a low-score review.

DROP TRIGGER IF EXISTS broadcast_review_finding ON inter_reviews;
DROP TRIGGER IF EXISTS link_review_to_issue_auto ON inter_reviews;
