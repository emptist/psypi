-- Migration: 078_update_table_documentation_inter_reviews.sql
-- Description: Update table documentation for inter_reviews to reflect renamed columns
--              reviewer_id → requester_id, reviewed_by → reviewer_id

UPDATE table_documentation SET
  purpose = 'Inter-AI review system for peer code reviews. Tracks review requests (requester_id), findings, scores, and responses (reviewer_id).',
  key_columns = '{
    "id": "UUID primary key",
    "task_id": "UUID reference to tasks",
    "commit_hash": "Git commit hash being reviewed",
    "branch": "Git branch",
    "requester_id": "Who requested the review",
    "reviewer_type": "ai or human",
    "reviewer_id": "Who performed the review",
    "status": "pending/in_progress/completed/failed",
    "overall_score": "Review score 0-100"
  }'::jsonb,
  updated_at = NOW()
WHERE table_name = 'inter_reviews';
