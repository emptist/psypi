-- 029e_low_findings_verification.sql
-- Verify all low/cosmetic findings against reality

-- ============================================================
-- FIX VERIFIED — mark as fixed
-- ============================================================
UPDATE review_findings SET status = 'fixed' WHERE finding_number = 352;
UPDATE review_findings SET status = 'fixed' WHERE finding_number = 353;
UPDATE review_findings SET status = 'fixed' WHERE finding_number = 354;

-- ============================================================
-- DUPLICATE FINDINGS
-- ============================================================
-- type_gap duplicates (same as #393)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (304, 306, 308, 329, 332, 333, 336, 403, 406);

-- missing_type duplicates (same as #393)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (359, 362, 364, 365, 367, 368, 371, 372, 373);

-- unused_columns duplicates (same as #407)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (239, 241, 242, 243);

-- structural_gap duplicates (same as #407)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (319, 320);

-- simple_migrate design duplicates (same as #270)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 225;

-- areflect data_quality duplicates (same as #2)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number IN (378, 379);

-- security duplicates (same as #155)
UPDATE review_findings SET status = 'duplicate' WHERE finding_number = 272;

-- ============================================================
-- RETRACTED FINDINGS
-- ============================================================
-- #383: task.gleam string_to_status both cases — NOT dead code, needed until casing standardization
UPDATE review_findings SET status = 'retracted', description = 'RETRACTED: string_to_status accepting both cases is a necessary workaround until CHECK constraint casing is standardized. The uppercase branch IS used by current DB data.' WHERE finding_number = 383;

-- ============================================================
-- CONFIRMED LOW FINDINGS
-- ============================================================
-- style
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 263;

-- design
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 268;

-- error_handling
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 273;

-- logic_error
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 257;

-- data_quality
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 340;

-- migration_risk
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 392;

-- missing_project_id
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 213;

-- test_coverage
UPDATE review_findings SET status = 'confirmed' WHERE finding_number IN (244, 254);

-- design_flaw
UPDATE review_findings SET status = 'confirmed' WHERE finding_number = 344;

-- ============================================================
-- VERIFICATION SUMMARY
-- ============================================================
SELECT 'LOW FINDINGS VERIFICATION SUMMARY' AS section;
SELECT status, COUNT(*) AS cnt FROM review_findings WHERE severity IN ('low','cosmetic') GROUP BY status ORDER BY cnt DESC;
