CREATE TABLE IF NOT EXISTS inter_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID,
    status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'in_progress', 'completed', 'failed')),
    summary TEXT,
    overall_score INTEGER,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_inter_reviews_status ON inter_reviews(status);
CREATE INDEX IF NOT EXISTS idx_inter_reviews_task ON inter_reviews(task_id);
