-- Migration: 035_drop_projects_table
-- The projects table was only used for a LEFT JOIN in views to get project_name.
-- Since project_name was always "psypi" (single row), we use skills.project_url instead.
-- The Gleam code never queries projects directly — project_url() reads from .git/config.

BEGIN;

-- Drop views that reference projects
DROP VIEW IF EXISTS approved_skills;
DROP VIEW IF EXISTS pending_skill_reviews;
DROP VIEW IF EXISTS pending_inter_reviews;

-- Drop the projects table
DROP TABLE IF EXISTS projects;

-- Recreate views without projects dependency
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

COMMIT;
