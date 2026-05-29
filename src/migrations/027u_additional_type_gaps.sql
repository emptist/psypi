-- 027u_additional_type_gaps.sql
-- Additional type gaps found during structural audit

-- #316: SkillSource missing AiBuilt variant - DB allows 'ai-built' but Gleam has no variant
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 316, 'high', 'type_gap', 'skill.gleam',
  'SkillSource missing AiBuilt variant - DB allows ai-built but Gleam has no variant',
  'skills.source CHECK allows: clawhub, local, generated, imported, ai-built. Gleam SkillSource has: Clawhub, Local, Generated, Imported. string_to_source has no case for "ai-built". Any skill with source=ai-built fails to decode.',
  'skill.gleam:9-14 SkillSource type. skill.gleam:48-55 string_to_source. DB: skills_source_check constraint.',
  'Skills created by AI builder are invisible to Gleam. Decode fails for ai-built source rows. This is a missing variant bug.');

-- #317: skills.scan_status has 5-value enum but no Gleam type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 317, 'medium', 'type_gap', 'skill.gleam',
  'skills.scan_status has 5-value enum but no Gleam type at all',
  'skills.scan_status CHECK allows: pending, clean, suspicious, malicious, reviewed. No Gleam type exists for scan_status. The column is not referenced in any Gleam code.',
  'DB: skills_scan_status_check. skill.gleam: no references to scan_status.',
  'Security scan results are invisible to Gleam. Cannot filter or display scan status. Malicious skills cannot be flagged in Gleam code.');

-- #318: skills.review_status has 6-value enum but no Gleam type
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 318, 'medium', 'type_gap', 'skill.gleam',
  'skills.review_status has 6-value enum but no Gleam type at all',
  'skills.review_status CHECK allows: pending, auto_passed, auto_failed, needs_manual_review, manually_approved, manually_rejected. No Gleam type exists for review_status. The column is not referenced in any Gleam code.',
  'DB: skills_review_status_check. skill.gleam: no references to review_status.',
  'Review workflow status is invisible to Gleam. Cannot track auto/manual review progress.');

-- #319: meeting_opinions.position column not in Gleam Opinion struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 319, 'low', 'structural_gap', 'meeting.gleam',
  'meeting_opinions.position column not in Gleam Opinion struct',
  'DB meeting_opinions has 8 columns. Gleam Opinion has 6 fields. Missing: position (text) and updated_at (timestamptz). position appears to store agreement/disagreement stance.',
  'meeting.gleam:28-37 Opinion struct. DB: meeting_opinions has position column.',
  'Opinion position/stance is lost when reading from DB. Minor gap.');

-- #320: projects.config (jsonb) not in Gleam Project struct
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 320, 'low', 'structural_gap', 'project.gleam',
  'projects.config (jsonb) not in Gleam Project struct',
  'DB projects has 14 columns. Gleam Project has 13 fields. Missing: config (jsonb). This stores project-specific configuration.',
  'project.gleam:22-37 Project struct. DB: projects has config jsonb.',
  'Project configuration is invisible to Gleam. Cannot read or modify project config.');

-- #321: system_reviews missing jsonb fields: findings, action_items, limitations
INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
VALUES ('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 321, 'medium', 'structural_gap', 'system_review_db.gleam',
  'system_reviews missing jsonb fields: findings, action_items, limitations',
  'DB system_reviews has 22 columns. Gleam SystemReview has 20 fields. Missing: findings (jsonb), action_items (jsonb), limitations (jsonb). These store structured review data. The SQL SELECT intentionally excludes them.',
  'system_review_db.gleam:261-268 SELECT excludes findings/action_items/limitations. system_review_types.gleam:62-82 SystemReview struct.',
  'Review findings stored directly on system_reviews are invisible. These jsonb fields may be legacy (findings now in review_findings table) but action_items and limitations contain unique data not stored elsewhere.');

-- Update type_inventory for skills.source
UPDATE type_inventory
SET gap_status = 'missing_variant',
    gap_detail = 'DB has ai-built (5 values). Gleam SkillSource has 4 variants. Missing AiBuilt.',
    gleam_variants = ARRAY['Clawhub','Local','Generated','Imported']
WHERE table_name = 'skills' AND column_name = 'source';

-- Add skills.scan_status to type_inventory
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'scan_status',
  ARRAY['pending','clean','suspicious','malicious','reviewed'],
  NULL, NULL,
  'no_gleam_type', '5-value enum with no Gleam type. Not referenced in any Gleam code.', true);

-- Add skills.review_status to type_inventory
INSERT INTO type_inventory (table_name, column_name, db_values, gleam_type_name, gleam_variants, gap_status, gap_detail, used_by_psypi)
VALUES ('skills', 'review_status',
  ARRAY['pending','auto_passed','auto_failed','needs_manual_review','manually_approved','manually_rejected'],
  NULL, NULL,
  'no_gleam_type', '6-value enum with no Gleam type. Not referenced in any Gleam code.', true);
