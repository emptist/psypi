CREATE TABLE IF NOT EXISTS code_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path TEXT NOT NULL,
    content TEXT NOT NULL,
    saved_by VARCHAR(255) NOT NULL DEFAULT '',
    commit_hash VARCHAR(255) NOT NULL DEFAULT '',
    reason TEXT NOT NULL DEFAULT '',
    saved_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_code_versions_file ON code_versions(file_path);
CREATE INDEX IF NOT EXISTS idx_code_versions_saved_at ON code_versions(saved_at DESC);

CREATE OR REPLACE FUNCTION save_code_version(
    p_file_path TEXT,
    p_content TEXT,
    p_saved_by VARCHAR,
    p_commit_hash VARCHAR,
    p_reason TEXT
) RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO code_versions (file_path, content, saved_by, commit_hash, reason)
    VALUES (p_file_path, p_content, p_saved_by, p_commit_hash, p_reason)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_code_versions(
    p_file_path TEXT,
    p_limit INTEGER
) RETURNS TABLE (
    id UUID,
    file_path TEXT,
    saved_by VARCHAR,
    commit_hash VARCHAR,
    reason TEXT,
    saved_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT cv.id, cv.file_path, cv.saved_by, cv.commit_hash, cv.reason, cv.saved_at
    FROM code_versions cv
    WHERE cv.file_path = p_file_path
    ORDER BY cv.saved_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION restore_code_version(
    p_id UUID
) RETURNS TEXT AS $$
DECLARE
    v_content TEXT;
BEGIN
    SELECT content INTO v_content FROM code_versions WHERE id = p_id;
    IF v_content IS NULL THEN
        RAISE EXCEPTION 'Version % not found', p_id;
    END IF;
    RETURN v_content;
END;
$$ LANGUAGE plpgsql;
