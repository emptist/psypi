-- Migration: 052_rename_reviewer_id_to_requester_id
-- Description: Fix illegal naming - reviewer_id actually stores requester (not reviewer)
-- The actual reviewer is stored in 'reviewed_by' column

-- 1. Rename column from reviewer_id to requester_id
ALTER TABLE inter_reviews RENAME COLUMN reviewer_id TO requester_id;

-- 2. Drop existing function before recreating with new parameter name
DROP FUNCTION IF EXISTS request_inter_review(uuid, text, text, text, jsonb);

-- 3. Recreate function with correct parameter name
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

-- 4. Update view to use new column name (using ALTER VIEW)
CREATE OR REPLACE VIEW pending_inter_reviews AS
SELECT 
    ir.id,
    ir.task_id,
    t.title as task_title,
    ir.commit_hash,
    ir.branch,
    ir.requester_id,  -- FIXED: was reviewer_id
    ir.requested_at,
    ir.review_round,
    ir.overall_score,
    EXTRACT(EPOCH FROM (NOW() - ir.requested_at)) / 60 as pending_minutes
FROM inter_reviews ir
LEFT JOIN tasks t ON ir.task_id = t.id
WHERE ir.status = 'pending'
ORDER BY ir.requested_at ASC;

-- 5. Update index name
DROP INDEX IF EXISTS idx_inter_reviews_reviewer_id;
CREATE INDEX IF NOT EXISTS idx_inter_reviews_requester_id ON inter_reviews(requester_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO PUBLIC;
