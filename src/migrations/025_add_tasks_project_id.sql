-- Migration: 025_add_tasks_project_id
-- Description: Add project_id column to tasks table (was added manually to DB but missing from migrations)
-- Also adds index on project_id for filtering performance

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS project_id TEXT;
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
