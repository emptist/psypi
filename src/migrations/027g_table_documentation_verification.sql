UPDATE table_documentation 
SET key_columns = '{
  "id": "UUID primary key",
  "review_type": "code/design/qc/peer/task/security/other",
  "status": "pending/in_progress/completed/follow_up/closed",
  "target_id": "What is being reviewed (project name)",
  "target_type": "Type of target (project/code/architecture/document)",
  "reviewer_id": "Who performed the review",
  "project_id": "UUID FK to projects table",
  "methodology": "document_analysis/code_comparison/git_log/concept_understanding/mixed",
  "scope": "full/partial/focused",
  "follow_up_status": "none/scheduled/overdue/completed",
  "git_hash": "Git commit hash at review time",
  "git_branch": "Git branch at review time",
  "related_issue_id": "UUID reference to issues"
}'::jsonb,
cli_commands = '[
  {"cmd": "psypi-review-list", "desc": "List all system reviews (Pi TUI tool)"},
  {"cmd": "psypi-review-get <id>", "desc": "Get a specific review by UUID (Pi TUI tool)"},
  {"cmd": "psypi-reviews", "desc": "List reviews with filters (Pi TUI tool)"}
]'::jsonb,
example_queries = '[
  {"desc": "List recent system reviews", "query": "SELECT id::text, review_type, status, methodology, scope, created_at::text FROM system_reviews ORDER BY created_at DESC LIMIT 5;"},
  {"desc": "Get review with finding counts by severity", "query": "SELECT r.id::text, r.review_type, r.status, COUNT(f.id) as finding_count, COUNT(f.id) FILTER (WHERE f.severity = ''critical'') as critical_count, COUNT(f.id) FILTER (WHERE f.severity = ''high'') as high_count FROM system_reviews r LEFT JOIN review_findings f ON f.review_id = r.id GROUP BY r.id ORDER BY r.created_at DESC;"},
  {"desc": "Find completed code comparison reviews", "query": "SELECT * FROM system_reviews WHERE methodology = ''code_comparison'' AND status = ''completed'';"}
]'::jsonb,
notes = 'Added methodology, scope, limitations columns 2026-05-15. Replaces old reviews table which was a nezha leftover. Findings moved to review_findings table 2026-05-27. Use review_findings for structured findings instead of JSONB findings field.',
updated_at = now()
WHERE table_name = 'system_reviews';

UPDATE table_documentation 
SET cli_commands = '[
  {"cmd": "psypi-findings <review_id>", "desc": "List findings for a review (Pi TUI tool)"},
  {"cmd": "psypi-finding-count <review_id>", "desc": "Count findings by severity/category (Pi TUI tool)"},
  {"cmd": "psypi-finding-update <review_id> <number> <status>", "desc": "Update finding status: open/confirmed/disputed/fixed/wont_fix/duplicate/retracted (Pi TUI tool)"},
  {"cmd": "psypi-finding-add <review_id>", "desc": "Add a new finding to a review (Pi TUI tool)"},
  {"cmd": "psypi-review-severity <review_id>", "desc": "Severity breakdown for a review (Pi TUI tool)"}
]'::jsonb,
example_queries = '[
  {"desc": "List all findings for current review", "query": "SELECT finding_number, severity, category, module, title, status FROM review_findings WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' ORDER BY CASE severity WHEN ''critical'' THEN 1 WHEN ''high'' THEN 2 WHEN ''medium'' THEN 3 WHEN ''low'' THEN 4 END, finding_number;"},
  {"desc": "Verify a specific finding against source code", "query": "SELECT finding_number, title, evidence FROM review_findings WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND finding_number = 215;"},
  {"desc": "Count findings by severity", "query": "SELECT severity, COUNT(*) FROM review_findings WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND status != ''retracted'' GROUP BY severity ORDER BY MIN(CASE severity WHEN ''critical'' THEN 1 WHEN ''high'' THEN 2 WHEN ''medium'' THEN 3 WHEN ''low'' THEN 4 END);"},
  {"desc": "Find all disputed or retracted findings", "query": "SELECT finding_number, severity, title, status FROM review_findings WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND status IN (''disputed'', ''retracted'') ORDER BY finding_number;"},
  {"desc": "Check which modules have the most findings", "query": "SELECT module, COUNT(*) as finding_count, COUNT(*) FILTER (WHERE severity IN (''critical'', ''high'')) as critical_or_high FROM review_findings WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND status = ''open'' GROUP BY module ORDER BY critical_or_high DESC, finding_count DESC;"},
  {"desc": "Dispute a finding (set status to disputed)", "query": "UPDATE review_findings SET status = ''disputed'', impact = ''Counter-evidence: ...'', updated_at = now() WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND finding_number = 999;"},
  {"desc": "Confirm a finding after verification", "query": "UPDATE review_findings SET status = ''confirmed'', updated_at = now() WHERE review_id = ''ca9e914c-cce6-4db4-b3b1-29779d8e1837'' AND finding_number = 999;"}
]'::jsonb,
notes = 'Created 2026-05-27 as part of database-first review strategy. 96 findings seeded from system review ca9e914c-cce6-4db4-b3b1-29779d8e1837. Each finding has evidence field pointing to specific source code lines. To verify a finding: 1) read the evidence field, 2) check the source code at the referenced line, 3) query information_schema.columns to verify DB schema claims, 4) set status to confirmed or disputed accordingly.',
updated_at = now()
WHERE table_name = 'review_findings';
