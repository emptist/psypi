-- Update system_reviews documentation
UPDATE table_documentation 
SET purpose = 'System-level reviews for project analysis, architecture evaluation, and cross-project comparison. Different from inter_reviews which are code-level peer reviews. Findings stored in review_findings table (not JSONB).',
    related_tables = ARRAY['issues', 'inter_reviews', 'review_findings'],
    updated_at = now()
WHERE table_name = 'system_reviews';

-- Add review_findings documentation
INSERT INTO table_documentation (table_name, purpose, usage_context, key_columns, related_tables, ai_can_modify, created_by, notes, tags)
VALUES (
  'review_findings',
  'Individual findings within a system review. Each finding has severity, category, module, title, description, evidence, impact, and status. Replaces the old JSONB findings array in system_reviews.',
  'Used by system review tools to track, query, and update individual findings. Supports filtering by severity, category, status, and module.',
  '{"id": "UUID primary key", "review_id": "UUID FK to system_reviews (CASCADE)", "finding_number": "Sequential number within review", "severity": "critical/high/medium/low/cosmetic", "category": "missing_cast/type_mismatch/design_flaw/etc", "module": "Gleam module name", "title": "Short finding title", "description": "Detailed finding description", "evidence": "Source code evidence", "impact": "What happens if not fixed", "status": "open/confirmed/disputed/fixed/wont_fix/duplicate/retracted", "related_issue_id": "UUID FK to issues"}'::jsonb,
  ARRAY['system_reviews', 'issues'],
  true,
  'trae-ai',
  'Created 2026-05-27 as part of database-first review strategy. 96 findings seeded from system review ca9e914c-cce6-4db4-b3b1-29779d8e1837.',
  ARRAY['review', 'findings', 'system-review']
) ON CONFLICT (table_name) DO UPDATE SET
  purpose = EXCLUDED.purpose,
  usage_context = EXCLUDED.usage_context,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  notes = EXCLUDED.notes,
  tags = EXCLUDED.tags,
  updated_at = now();
