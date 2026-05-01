-- Migration: 075_fix_inter_reviews_naming
-- Description: Fix naming confusion in inter_reviews table
--              reviewer_id actually stores the requester (not reviewer)
--              reviewed_by actually stores the reviewer
--              Swap names to be semantically correct

-- Since tables are empty (confirmed 0 rows), we can safely rename columns

-- 1. Rename reviewer_id to requester_id (this column stores who REQUESTED the review)
ALTER TABLE inter_reviews RENAME COLUMN reviewer_id TO requester_id;

-- 2. Rename reviewed_by to reviewer_id (this column stores who PERFORMED the review)
ALTER TABLE inter_reviews RENAME COLUMN reviewed_by TO reviewer_id;

-- 3. Drop and recreate the request_inter_review function with correct parameter names
DROP FUNCTION IF EXISTS request_inter_review(uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS request_inter_review(uuid, text, text, text);

CREATE OR REPLACE FUNCTION request_inter_review(
    p_task_id UUID,
    p_commit_hash TEXT,
    p_branch TEXT,
    p_requester_id TEXT,  -- FIXED: was incorrectly named p_reviewer_id
    p_review_context JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
    v_existing_id UUID;
    v_existing_status TEXT;
BEGIN
    -- Check for existing pending/in_progress review for this task
    SELECT id, status INTO v_existing_id, v_existing_status 
    FROM inter_reviews 
    WHERE task_id = p_task_id 
      AND status IN ('pending', 'in_progress')
    ORDER BY requested_at DESC
    LIMIT 1;
    
    -- If there's a pending/in_progress review, reuse it
    IF v_existing_id IS NOT NULL THEN
        RETURN v_existing_id;
    END IF;
    
    -- Otherwise create a new review
    INSERT INTO inter_reviews (
        task_id, commit_hash, branch, requester_id, status, review_context, requested_at
    ) VALUES (
        p_task_id, p_commit_hash, p_branch, p_requester_id, 'pending', p_review_context, NOW()
    )
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- 4. Drop and recreate the update_inter_review function (may reference reviewer_id)
DROP FUNCTION IF EXISTS update_inter_review(uuid, text, text, jsonb, jsonb, jsonb, jsonb, integer, integer, integer, integer, text);

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
    p_raw_response TEXT DEFAULT NULL
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
        completed_at = CASE WHEN p_status = 'completed' THEN NOW() ELSE completed_at END
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Update the pending_inter_reviews view
CREATE OR REPLACE VIEW pending_inter_reviews AS
SELECT 
    ir.id,
    ir.task_id,
    t.title as task_title,
    ir.commit_hash,
    ir.branch,
    ir.requester_id,  -- FIXED: was reviewer_id
    ir.reviewer_id,    -- NEW: show who is doing the review
    ir.requested_at,
    ir.review_round,
    ir.overall_score,
    EXTRACT(EPOCH FROM (NOW() - ir.requested_at)) / 60 as pending_minutes
FROM inter_reviews ir
LEFT JOIN tasks t ON ir.task_id = t.id
WHERE ir.status = 'pending'
ORDER BY ir.requested_at ASC;

-- 6. Update the inter_review_stats view (if reviewer_id is used)
CREATE OR REPLACE VIEW inter_review_stats AS
SELECT 
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
    COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
    AVG(overall_score) FILTER (WHERE overall_score IS NOT NULL) as avg_score,
    AVG(code_quality_score) FILTER (WHERE code_quality_score IS NOT NULL) as avg_code_quality,
    AVG(test_coverage_score) FILTER (WHERE test_coverage_score IS NOT NULL) as avg_test_coverage,
    AVG(documentation_score) FILTER (WHERE documentation_score IS NOT NULL) as avg_documentation,
    COUNT(DISTINCT requester_id) as unique_requesters,
    COUNT(DISTINCT reviewer_id) FILTER (WHERE reviewer_id IS NOT NULL) as unique_reviewers
FROM inter_reviews;

-- 7. Recreate indexes with correct names
DROP INDEX IF EXISTS idx_inter_reviews_reviewer_id;
CREATE INDEX IF NOT EXISTS idx_inter_reviews_requester_id ON inter_reviews(requester_id);
CREATE INDEX IF NOT EXISTS idx_inter_reviews_reviewer_id ON inter_reviews(reviewer_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;
