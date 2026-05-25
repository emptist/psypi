-- Migration: 025_add_tasks_project_id
-- Description: Add project_id column to tasks table (was added manually to DB but missing from migrations)
-- Also adds index on project_id for filtering performance and sets default project

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS project_id UUID;
ALTER TABLE tasks ALTER COLUMN project_id SET DEFAULT '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
