-- Migration: 034_project_id_to_project_url_combined
-- Combined execution of 032 (backfill) + 033 (structural rename) + fixes
-- Renames project_id → project_url across all 24 tables and project_fingerprint → project_url in project_visits
-- Backfills data from projects.git_remote

-- Step 1: Add project_url columns
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE skills ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE project_metrics ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE project_config_history ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE archived_memory ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE learning_insights ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE skill_audit_log ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE skill_feedback ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE system_reviews ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE task_outcomes ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE task_patterns ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE memory ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE project_communications ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE inter_reviews ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE agent_configs ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE heartbeat_configs ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE project_skills ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE task_results ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE tool_definitions ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS project_url text;
ALTER TABLE project_visits ADD COLUMN IF NOT EXISTS project_url text;

-- Step 2: Backfill from projects.git_remote (UUID FK tables)
UPDATE tasks SET project_url = (SELECT git_remote FROM projects WHERE id = tasks.project_id);
UPDATE issues SET project_url = (SELECT git_remote FROM projects WHERE id = issues.project_id);
UPDATE meetings SET project_url = (SELECT git_remote FROM projects WHERE id = meetings.project_id);
UPDATE conversations SET project_url = (SELECT git_remote FROM projects WHERE id = conversations.project_id);
UPDATE skills SET project_url = (SELECT git_remote FROM projects WHERE id = skills.project_id);
UPDATE project_metrics SET project_url = (SELECT git_remote FROM projects WHERE id = project_metrics.project_id);
UPDATE project_config_history SET project_url = (SELECT git_remote FROM projects WHERE id = project_config_history.project_id);
UPDATE archived_memory SET project_url = (SELECT git_remote FROM projects WHERE id = archived_memory.project_id) WHERE project_id IS NOT NULL;
UPDATE learning_insights SET project_url = (SELECT git_remote FROM projects WHERE id = learning_insights.project_id) WHERE project_id IS NOT NULL;
UPDATE skill_audit_log SET project_url = (SELECT git_remote FROM projects WHERE id = skill_audit_log.project_id) WHERE project_id IS NOT NULL;
UPDATE skill_feedback SET project_url = (SELECT git_remote FROM projects WHERE id = skill_feedback.project_id) WHERE project_id IS NOT NULL;
UPDATE system_reviews SET project_url = (SELECT git_remote FROM projects WHERE id = system_reviews.project_id) WHERE project_id IS NOT NULL;
UPDATE task_outcomes SET project_url = (SELECT git_remote FROM projects WHERE id = task_outcomes.project_id) WHERE project_id IS NOT NULL;
UPDATE task_patterns SET project_url = (SELECT git_remote FROM projects WHERE id = task_patterns.project_id) WHERE project_id IS NOT NULL;
UPDATE memory SET project_url = (SELECT git_remote FROM projects WHERE id = memory.project_id) WHERE project_id IS NOT NULL;
UPDATE project_communications SET project_url = (SELECT git_remote FROM projects WHERE id = project_communications.project_id);
UPDATE inter_reviews SET project_url = (SELECT git_remote FROM projects WHERE id = (SELECT project_id FROM tasks WHERE id = inter_reviews.task_id)) WHERE task_id IS NOT NULL;

-- Step 3: Text project_id columns — copy directly
UPDATE agent_configs SET project_url = project_id;
UPDATE heartbeat_configs SET project_url = project_id;
UPDATE project_skills SET project_url = project_id;
UPDATE task_results SET project_url = project_id;
UPDATE tool_definitions SET project_url = project_id;
UPDATE user_profiles SET project_url = project_id;

-- Step 4: project_visits — use git_remote instead of fingerprint
UPDATE project_visits SET project_url = (SELECT git_remote FROM projects WHERE fingerprint = project_visits.project_url);

-- Step 5: Drop dependent views before column drops
DROP VIEW IF EXISTS pending_inter_reviews;
DROP VIEW IF EXISTS approved_skills;
DROP VIEW IF EXISTS pending_skill_reviews;

-- Step 6: Drop FK constraints
ALTER TABLE IF EXISTS tasks DROP CONSTRAINT IF EXISTS tasks_project_id_fkey;
ALTER TABLE IF EXISTS issues DROP CONSTRAINT IF EXISTS issues_project_id_fkey;
ALTER TABLE IF EXISTS meetings DROP CONSTRAINT IF EXISTS meetings_project_id_fkey;
ALTER TABLE IF EXISTS conversations DROP CONSTRAINT IF EXISTS conversations_project_id_fkey;
ALTER TABLE IF EXISTS skills DROP CONSTRAINT IF EXISTS skills_project_id_fkey;
ALTER TABLE IF EXISTS project_metrics DROP CONSTRAINT IF EXISTS project_metrics_project_id_fkey;
ALTER TABLE IF EXISTS inter_reviews DROP CONSTRAINT IF EXISTS inter_reviews_task_id_fkey;

-- Step 7: Drop RLS policies
DROP POLICY IF EXISTS memory_project_isolation ON memory;
DROP POLICY IF EXISTS issues_project_isolation ON issues;
DROP POLICY IF EXISTS tasks_project_isolation ON tasks;
DROP POLICY IF EXISTS conversations_project_isolation ON conversations;

-- Step 8: Drop old project_id / project_fingerprint columns
ALTER TABLE tasks DROP COLUMN IF EXISTS project_id;
ALTER TABLE issues DROP COLUMN IF EXISTS project_id;
ALTER TABLE meetings DROP COLUMN IF EXISTS project_id;
ALTER TABLE conversations DROP COLUMN IF EXISTS project_id;
ALTER TABLE skills DROP COLUMN IF EXISTS project_id;
ALTER TABLE project_metrics DROP COLUMN IF EXISTS project_id;
ALTER TABLE project_config_history DROP COLUMN IF EXISTS project_id;
ALTER TABLE archived_memory DROP COLUMN IF EXISTS project_id;
ALTER TABLE learning_insights DROP COLUMN IF EXISTS project_id;
ALTER TABLE skill_audit_log DROP COLUMN IF EXISTS project_id;
ALTER TABLE skill_feedback DROP COLUMN IF EXISTS project_id;
ALTER TABLE system_reviews DROP COLUMN IF EXISTS project_id;
ALTER TABLE task_outcomes DROP COLUMN IF EXISTS project_id;
ALTER TABLE task_patterns DROP COLUMN IF EXISTS project_id;
ALTER TABLE memory DROP COLUMN IF EXISTS project_id;
ALTER TABLE project_communications DROP COLUMN IF EXISTS project_id;
ALTER TABLE inter_reviews DROP COLUMN IF EXISTS task_id;
ALTER TABLE agent_configs DROP COLUMN IF EXISTS project_id;
ALTER TABLE heartbeat_configs DROP COLUMN IF EXISTS project_id;
ALTER TABLE project_skills DROP COLUMN IF EXISTS project_id;
ALTER TABLE task_results DROP COLUMN IF EXISTS project_id;
ALTER TABLE tool_definitions DROP COLUMN IF EXISTS project_id;
ALTER TABLE user_profiles DROP COLUMN IF EXISTS project_id;
ALTER TABLE project_visits DROP COLUMN IF EXISTS project_fingerprint;

-- Step 9: Set NOT NULL
ALTER TABLE tasks ALTER COLUMN project_url SET NOT NULL;
ALTER TABLE issues ALTER COLUMN project_url SET NOT NULL;

-- Step 10: Change allowed_projects uuid[] → text[]
ALTER TABLE skills ALTER COLUMN allowed_projects TYPE text[] USING allowed_projects::text[];

-- Step 11: Recreate views
CREATE VIEW approved_skills AS
SELECT s.id,
    s.project_url AS project_id,
    s.name, s.source, s.external_id, s.version, s.description, s.author, s.repository,
    s.tags, s.safety_score, s.scan_status, s.verified, s.downloads, s.rating, s.status,
    s.approved_by, s.approved_at, s.rejection_reason, s.is_enabled, s.is_public,
    s.allowed_users, s.allowed_projects, s.use_count, s.last_used_at, s.installed_at,
    s.warnings, s.issues, s.permissions, s.code_analysis, s.review_notes, s.reviewed_at,
    s.reviewed_by, s.review_status, s.auto_review_score, s.manual_review_required,
    s.instructions, s.manifest, s.content_hash, s.created_at, s.updated_at, s.builder,
    s.maintainer, s.build_metadata, s.generation_prompt, s.category, s.content,
    s.trigger_phrases, s.anti_patterns, s.quick_start, s.examples, s.embedding,
    s.viewers,
    s.project_url AS project_name
FROM skills s
WHERE s.status = 'approved' AND s.is_enabled = true
ORDER BY s.rating DESC, s.safety_score DESC;

CREATE VIEW pending_skill_reviews AS
SELECT s.id,
    s.project_url AS project_id,
    s.name, s.source, s.external_id, s.version, s.description, s.author, s.repository,
    s.tags, s.safety_score, s.scan_status, s.verified, s.downloads, s.rating, s.status,
    s.approved_by, s.approved_at, s.rejection_reason, s.is_enabled, s.is_public,
    s.allowed_users, s.allowed_projects, s.use_count, s.last_used_at, s.installed_at,
    s.warnings, s.issues, s.permissions, s.code_analysis, s.review_notes, s.reviewed_at,
    s.reviewed_by, s.review_status, s.auto_review_score, s.manual_review_required,
    s.instructions, s.manifest, s.content_hash, s.created_at, s.updated_at, s.builder,
    s.maintainer, s.build_metadata, s.generation_prompt, s.category, s.content,
    s.trigger_phrases, s.anti_patterns, s.quick_start, s.examples, s.embedding,
    s.viewers,
    s.project_url AS project_name
FROM skills s
WHERE s.status = 'pending' OR (s.review_status = 'needs_manual_review' AND s.status = 'approved')
ORDER BY s.safety_score, s.created_at DESC;

CREATE VIEW pending_inter_reviews AS
SELECT ir.id,
    NULL::text AS task_id,
    ir.project_url,
    t.title AS task_title,
    ir.commit_hash, ir.branch, ir.requester_id, ir.reviewer_id,
    ir.requested_at, ir.review_round, ir.overall_score,
    EXTRACT(epoch FROM (now() - ir.requested_at)) / 60 AS pending_minutes
FROM inter_reviews ir
LEFT JOIN tasks t ON t.project_url = ir.project_url
WHERE ir.status = 'pending'
ORDER BY ir.requested_at;
