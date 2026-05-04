-- Create code_versions table to protect against "stupid AI" disasters
-- Save code BEFORE AI modifies it!

CREATE TABLE IF NOT EXISTS code_versions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_path TEXT NOT NULL,
  content TEXT NOT NULL,
  version_hash VARCHAR(64) NOT NULL, -- SHA-256 hash
  saved_by VARCHAR(255) NOT NULL,
  saved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  commit_hash VARCHAR(255),
  reason TEXT, -- Why was this saved? (e.g., "before AI edit", "pre-disaster backup")
  
  -- Metadata
  project_name VARCHAR(100) DEFAULT 'psypi',
  file_size INTEGER,
  line_count INTEGER,
  
  CONSTRAINT unique_file_version UNIQUE(file_path, version_hash)
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_code_versions_file_path ON code_versions(file_path);
CREATE INDEX IF NOT EXISTS idx_code_versions_saved_at ON code_versions(saved_at DESC);
CREATE INDEX IF NOT EXISTS idx_code_versions_saved_by ON code_versions(saved_by);

-- Table documentation
INSERT INTO table_documentation (table_name, purpose, ai_can_modify)
VALUES ('code_versions', 'Code versioning/protection - saves code BEFORE AI modifies. Prevents disasters!', false)
ON CONFLICT (table_name) DO UPDATE SET purpose = EXCLUDED.purpose, ai_can_modify = EXCLUDED.ai_can_modify;

-- Function to save a file version
CREATE OR REPLACE FUNCTION save_code_version(
  p_file_path TEXT,
  p_content TEXT,
  p_saved_by VARCHAR(255),
  p_commit_hash VARCHAR(255) DEFAULT NULL,
  p_reason TEXT DEFAULT 'before AI edit'
) RETURNS UUID AS $$
DECLARE
  v_hash VARCHAR(64);
  v_id UUID;
BEGIN
  -- Calculate SHA-256 hash
  v_hash := encode(digest(p_content, 'sha256'), 'hex');
  
  -- Check if this version already exists
  SELECT id INTO v_id FROM code_versions 
  WHERE file_path = p_file_path AND version_hash = v_hash;
  
  IF v_id IS NOT NULL THEN
    RETURN v_id; -- Version already saved
  END IF;
  
  -- Save new version
  INSERT INTO code_versions (file_path, content, version_hash, saved_by, commit_hash, reason, file_size, line_count)
  VALUES (
    p_file_path, 
    p_content, 
    v_hash, 
    p_saved_by, 
    p_commit_hash,
    p_reason,
    length(p_content),
    (SELECT COUNT(*) FROM regexp_split_to_table(p_content, E'\\n'))
  )
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Function to restore a file version
CREATE OR REPLACE FUNCTION restore_code_version(
  p_version_id UUID
) RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  SELECT content INTO v_content FROM code_versions WHERE id = p_version_id;
  RETURN v_content;
END;
$$ LANGUAGE plpgsql;

-- Function to get version history for a file
CREATE OR REPLACE FUNCTION get_code_versions(
  p_file_path TEXT,
  p_limit INTEGER DEFAULT 10
) RETURNS TABLE (
  id UUID,
  version_hash VARCHAR(64),
  saved_by VARCHAR(255),
  saved_at TIMESTAMP WITH TIME ZONE,
  commit_hash VARCHAR(255),
  reason TEXT,
  file_size INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT cv.id, cv.version_hash, cv.saved_by, cv.saved_at, cv.commit_hash, cv.reason, cv.file_size
  FROM code_versions cv
  WHERE cv.file_path = p_file_path
  ORDER BY cv.saved_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
