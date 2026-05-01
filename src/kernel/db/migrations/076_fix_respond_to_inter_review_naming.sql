-- Migration: 076_fix_respond_to_inter_review_naming.sql
-- Description: Fix respond_to_inter_review function to use renamed columns
--              reviewed_by was renamed to reviewer_id

-- Drop the old function
DROP FUNCTION IF EXISTS respond_to_inter_review(uuid, text, jsonb, text, text, numeric, integer, integer);

-- Recreate with correct column name
CREATE OR REPLACE FUNCTION respond_to_inter_review(
    p_id UUID,
    p_response TEXT,
    p_accepted_suggestions JSONB DEFAULT '[]'::jsonb,
    p_reviewer_id TEXT DEFAULT NULL,  -- FIXED: was p_reviewed_by
    p_response_status TEXT DEFAULT 'accepted',
    p_leverage_ratio DECIMAL DEFAULT NULL,
    p_rework_count INTEGER DEFAULT 0,
    p_effort_minutes INTEGER DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(SELECT 1 FROM inter_reviews WHERE id = p_id) INTO v_exists;
    
    IF NOT v_exists THEN
        RAISE EXCEPTION 'Inter-review with id % does not exist', p_id;
    END IF;
    
    UPDATE inter_reviews SET
        response = p_response,
        response_at = NOW(),
        accepted_suggestions = p_accepted_suggestions,
        reviewer_id = COALESCE(p_reviewer_id, reviewer_id),  -- FIXED: was reviewed_by
        response_status = p_response_status,
        leverage_ratio = p_leverage_ratio,
        rework_count = p_rework_count,
        effort_minutes = p_effort_minutes
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION respond_to_inter_review(uuid, text, jsonb, text, text, numeric, integer, integer) TO PUBLIC;
