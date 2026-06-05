-- Migration 048: Convert skills to append-only
--
-- Converts skills table from UPDATE-in-place to append-only pattern.
-- Adds is_active and is_archived columns, partial unique index on
-- (name) WHERE is_active = true, and save_skill_version() SQL function.
--
-- DESIGN:
--   is_active = true  → current version (at most one per skill name)
--   is_archived = false → visible to application
--   READ PATH: WHERE is_active = true AND is_archived = false
--   WRITE PATH: save_skill_version() — never UPDATE in place for content changes
--   STATE CHANGES: approve/reject remain as UPDATE-in-place (state machine)
--
-- ONLINE-SAFE NOTES:
--   Table size: currently 0 rows (empty)
--   Lock duration: < 1 second
--   Pi can stay running: yes

-- ═══════════════════════════════════════════════════════════════════
-- 1. Add columns
-- ═══════════════════════════════════════════════════════════════════

ALTER TABLE skills
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE skills
  ADD COLUMN IF NOT EXISTS is_archived boolean NOT NULL DEFAULT false;

-- ═══════════════════════════════════════════════════════════════════
-- 2. Create partial unique index on (name) WHERE is_active = true
--    Ensures at most one active version per skill name
-- ═══════════════════════════════════════════════════════════════════

CREATE UNIQUE INDEX IF NOT EXISTS uq_skills_active_name
  ON skills (name) WHERE is_active = true;

-- ═══════════════════════════════════════════════════════════════════
-- 3. Backfill: ensure all existing rows have flags set correctly
--    (idempotent — only affects rows where flags are not yet set)
-- ═══════════════════════════════════════════════════════════════════

UPDATE skills SET is_active = true, is_archived = false
WHERE is_active IS NULL OR is_archived IS NULL;

-- ═══════════════════════════════════════════════════════════════════
-- 4. SQL function for append-only writes
--    Deactivates old version, inserts new version copying stable fields
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION save_skill_version(
  p_name         text,
  p_content      jsonb,
  p_version      text,
  p_change_summary text,
  p_improved_by  text
) RETURNS uuid AS $$
DECLARE
  v_new_id uuid;
BEGIN
  -- Deactivate current active version
  UPDATE skills
     SET is_active = false
   WHERE name = p_name
     AND is_active = true;

  -- Insert new version, copying stable fields from the most recent row
  INSERT INTO skills (
    name, source, external_id, description, author, repository,
    tags, safety_score, scan_status, verified, downloads, rating,
    status, approved_by, approved_at, rejection_reason,
    is_enabled, is_public, allowed_users, allowed_projects,
    use_count, last_used_at, installed_at, warnings, issues,
    permissions, code_analysis, review_notes, reviewed_at,
    reviewed_by, review_status, auto_review_score,
    manual_review_required, instructions, manifest,
    content_hash, builder, maintainer, build_metadata,
    generation_prompt, category, content, trigger_phrases,
    anti_patterns, quick_start, examples, embedding,
    viewers, emoji, reference_list, references_json, project_url,
    is_active, is_archived
  )
  SELECT
    name, source, external_id, description, author, repository,
    tags, safety_score, scan_status, verified, downloads, rating,
    status, approved_by, approved_at, rejection_reason,
    is_enabled, is_public, allowed_users, allowed_projects,
    use_count, last_used_at, installed_at, warnings, issues,
    permissions, code_analysis, review_notes, reviewed_at,
    reviewed_by, review_status, auto_review_score,
    manual_review_required, instructions, manifest,
    content_hash, builder, maintainer, build_metadata,
    generation_prompt, category, p_content, trigger_phrases,
    anti_patterns, quick_start, examples, embedding,
    viewers, emoji, reference_list, references_json, project_url,
    true, false
  FROM skills
  WHERE name = p_name
  ORDER BY created_at DESC
  LIMIT 1
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    RAISE EXCEPTION 'save_skill_version: no previous row found for name=%, cannot copy metadata', p_name;
  END IF;

  -- Update version and change metadata on the new row
  UPDATE skills
     SET version = p_version,
         updated_at = now()
   WHERE id = v_new_id;

  RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- ═══════════════════════════════════════════════════════════════════
-- 5. Verification queries
-- ═══════════════════════════════════════════════════════════════════

-- Verify: no NULL flags
-- Expected: 0
SELECT COUNT(*) FROM skills WHERE is_active IS NULL OR is_archived IS NULL;

-- Verify: at most one active row per name
-- Expected: 0 rows
SELECT name, COUNT(*) as active_count
FROM skills WHERE is_active = true
GROUP BY name HAVING COUNT(*) > 1;
