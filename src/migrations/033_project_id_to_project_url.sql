-- Migration: 033_project_id_to_project_url
-- Structural changes: rename project_id → project_url, drop FKs, change types, drop defaults.
-- This migration is permanent and runs on every install.

-- Drop foreign key constraints on project_id
ALTER TABLE IF EXISTS tasks DROP CONSTRAINT IF EXISTS tasks_project_id_fkey;
ALTER TABLE IF EXISTS issues DROP CONSTRAINT IF EXISTS issues_project_id_fkey;
ALTER TABLE IF EXISTS meetings DROP CONSTRAINT IF EXISTS meetings_project_id_fkey;
ALTER TABLE IF EXISTS conversations DROP CONSTRAINT IF EXISTS conversations_project_id_fkey;
ALTER TABLE IF EXISTS skills DROP CONSTRAINT IF EXISTS skills_project_id_fkey;

-- Rename project_id → project_url in all 24 tables
ALTER TABLE IF EXISTS agent_configs RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS approved_skills RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS archived_memory RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS conversations RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS heartbeat_configs RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS issues RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS learning_insights RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS meetings RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS memory RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS pending_skill_reviews RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS project_communications RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS project_config_history RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS project_metrics RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS project_skills RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS skill_audit_log RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS skill_feedback RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS skills RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS system_reviews RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS task_outcomes RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS task_patterns RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS task_results RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS tasks RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS tool_definitions RENAME COLUMN project_id TO project_url;
ALTER TABLE IF EXISTS user_profiles RENAME COLUMN project_id TO project_url;

-- Drop UUID defaults (project_url has no default)
ALTER TABLE tasks ALTER COLUMN project_url DROP DEFAULT;
ALTER TABLE project_communications ALTER COLUMN project_url DROP DEFAULT;

-- Change uuid → text where needed
ALTER TABLE issues ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE project_communications ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE system_reviews ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE meetings ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE memory ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE conversations ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE skills ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE project_metrics ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE project_config_history ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE approved_skills ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE archived_memory ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE learning_insights ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE pending_skill_reviews ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE skill_audit_log ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE skill_feedback ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE task_outcomes ALTER COLUMN project_url TYPE text USING project_url::text;
ALTER TABLE task_patterns ALTER COLUMN project_url TYPE text USING project_url::text;

-- Enforce NOT NULL on tables that require project_url
ALTER TABLE system_reviews ALTER COLUMN project_url SET NOT NULL;

-- Drop RLS policies (no longer needed — project_url is explicit in queries)
DROP POLICY IF EXISTS memory_project_isolation ON memory;
DROP POLICY IF EXISTS issues_project_isolation ON issues;
DROP POLICY IF EXISTS tasks_project_isolation ON tasks;
DROP POLICY IF EXISTS conversations_project_isolation ON conversations;
