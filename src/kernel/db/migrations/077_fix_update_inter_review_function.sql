-- Migration: 077_fix_update_inter_review_function.sql
-- Description: Fix update_inter_review to include p_reviewer_id parameter
--              The TypeScript code calls this function with 13 parameters

-- Drop ALL versions of update_inter_review function
DO $$ 
DECLARE 
    func_oid oid; 
BEGIN 
    -- Find and drop all versions of update_inter_review
    FOR func_oid IN 
        SELECT p.oid 
        FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE p.proname = 'update_inter_review' 
        AND n.nspname = 'public' 
    LOOP 
        EXECUTE 'DROP FUNCTION IF EXISTS ' || func_oid::regprocedure; 
    END LOOP; 
END $$;

-- Recreate with correct signature (13 parameters to match TypeScript code)
CREATE OR REPLACE FUNCTION update_inter_review(
    p_id UUID,
    p_status TEXT DEFAULT NULL,
    p_summary TEXT DEFAULT NULL,
    p_findings JSONB DEFAULT NULL,
    p_suggestions JSONB DEFAULT NULL,
    p_issues JSONB DEFAULT NULL,
    p_praise JSONB DEFAULT NULL,
    p_overall_score INTEGER DEFAULT NULL,
    p_code_quality_score INTEGER DEFAULT NULL,
    p_test_coverage_score INTEGER DEFAULT NULL,
    p_documentation_score INTEGER DEFAULT NULL,
    p_raw_response TEXT DEFAULT NULL,
    p_reviewer_id TEXT DEFAULT NULL  -- FIXED: was p_reviewed_by
)
RETURNS VOID AS $$
BEGIN
    UPDATE inter_reviews SET
        status = COALESCE(p_status, status),
        summary = COALESCE(p_summary, summary),
        findings = COALESCE(p_findings, findings),
        suggestions = COALESCE(p_suggestions, suggestions),
        issues = COALESCE(p_issues, issues),
        praise = COALESCE(p_praise, praise),
        overall_score = COALESCE(p_overall_score, overall_score),
        code_quality_score = COALESCE(p_code_quality_score, code_quality_score),
        test_coverage_score = COALESCE(p_test_coverage_score, test_coverage_score),
        documentation_score = COALESCE(p_documentation_score, documentation_score),
        raw_response = COALESCE(p_raw_response, raw_response),
        reviewer_id = COALESCE(p_reviewer_id, reviewer_id),  -- FIXED: was reviewed_by
        completed_at = CASE WHEN p_status = 'completed' THEN NOW() ELSE completed_at END
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (already granted in earlier migrations)
-- GRANT EXECUTE ON FUNCTION update_inter_review(...) TO PUBLIC;
