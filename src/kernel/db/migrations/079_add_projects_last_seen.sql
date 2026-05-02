-- Add last_seen column to projects table
-- This column tracks when a project was last accessed/seen by the system

ALTER TABLE projects ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ DEFAULT NOW();

-- Update existing rows to have a last_seen value
UPDATE projects SET last_seen = NOW() WHERE last_seen IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN projects.last_seen IS 'Timestamp of when the project was last accessed or seen by the system';
