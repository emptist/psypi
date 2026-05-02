# Schema Differences: nezha vs psypi

## Overview
The psypi database has a significantly different schema compared to nezha. This document tracks the differences to enable proper data migration.

## Table: projects

### nezha columns:
- id, name, description, path, language, framework, config, status, created_at, updated_at, last_qc_at, fingerprint, type, last_seen

### psypi columns:
- id, name, description, path, language, framework, config, status, created_at, updated_at, last_qc_at

### Differences:
- **Missing in psypi**: `fingerprint`, `type`, `last_seen`
- **Action**: Skip these columns during migration (already handled)

---

## Table: skills

### nezha columns (39):
- id, name, description, version, category, content, tags, project_id (text), config, source, url, author, created_at, updated_at, builder, maintainer, build_metadata, generation_prompt, trigger_phrases, anti_patterns, quick_start, examples, emoji, embedding, safety_score, status, rating, instructions, manifest (text), external_id, scan_status, verified, permissions, is_enabled, use_count, last_used_at, installed_at, created_by, viewers

### psypi columns (53):
- id, project_id (uuid), name, source, external_id, version, description, author, repository, tags, safety_score, scan_status, verified, downloads, rating, status, approved_by, approved_at, rejection_reason, is_enabled, is_public, allowed_users, allowed_projects, use_count, last_used_at, installed_at, warnings, issues, permissions, code_analysis, review_notes, reviewed_at, reviewed_by, review_status, auto_review_score, manual_review_required, instructions, manifest (jsonb), content_hash, created_at, updated_at, builder, maintainer, build_metadata, generation_prompt, category, content, trigger_phrases, anti_patterns, quick_start, examples, embedding, viewers

### Differences:
- **project_id**: nezha has text, psypi has uuid
- **manifest**: nezha has text, psypi has jsonb
- **Missing in psypi**: `url`, `emoji`, `created_by`
- **Extra in psypi**: `repository`, `downloads`, `approved_by`, `approved_at`, `rejection_reason`, `is_public`, `allowed_users`, `allowed_projects`, `warnings`, `issues`, `code_analysis`, `review_notes`, `reviewed_at`, `reviewed_by`, `review_status`, `auto_review_score`, `manual_review_required`, `content_hash`
- **Action**: Migrated successfully (skipping url, emoji, created_by; leaving new columns as defaults)

---

## Table: tasks

### nezha columns:
- (Need to verify)

### psypi columns (from \d output):
- id, title, description, status, priority, result, error, retry_count, created_at, updated_at, completed_at, project_id, depends_on (uuid[]), blocking (uuid[]), base_priority, weighted_priority, last_error, tags, auto_tagged, encrypted_result, result_iv, next_retry_at, max_retries, timeout_seconds, started_at, is_long_running, type, assigned_to, category, error_category, consecutive_failures, last_failed_at, is_stuck, stuck_at, watchdog_kills, created_by, agent_id, agent_name, git_hash, git_branch, environment, session_id, executor_type, executor_model, executor_provider, delegate_to, complexity

### Differences:
- **Missing in psypi**: `parent_task_id` (from my incorrect assumption)
- **Action**: Remove `parent_task_id` from migration query

---

## Table: issues

### nezha columns:
- (Need to verify)

### psypi columns:
- id, title, description, issue_type, severity, status, discovered_by, discovered_at, related_issue_id, task_id, resolution, resolved_at, resolved_by, tags, metadata, created_at, updated_at, assignee, assignee_type, review_id, dlq_id, viewers

### Differences:
- **Missing in psypi**: `project_id`!
- **Action**: Issues in psypi don't have direct project_id. May be linked via `task_id` or `discovered_by`. Need to investigate further.

---

## Migration Status

| Table | Status | Notes |
|-------|--------|-------|
| projects | ✅ Done | Skipped fingerprint, type, last_seen |
| skills | ✅ Done | 638 skills migrated |
| tasks | ⚠️ Pending | Fix column mapping (remove parent_task_id) |
| issues | ⚠️ Pending | No project_id in psypi - need different approach |
| memory | ❌ Not started | |
| meetings | ❌ Not started | |
| agent_identities | ❌ Not started | |
| conversations | ❌ Not started | |

---

## Next Steps

1. Fix tasks migration (remove non-existent columns)
2. Investigate issues-project relationship in psypi
3. Continue with remaining tables
4. Update migration scripts to handle schema differences
