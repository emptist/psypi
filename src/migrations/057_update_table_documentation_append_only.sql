-- Migration 057: Update table_documentation for correct is_active/is_archived semantics
--
-- is_archived is the PRIMARY gate (historical = true, alive = false).
-- is_active is a BUSINESS flag (enabled/disabled), NOT touched by versioning.
-- Versioning functions (save_soul_version, save_job_version) ONLY set
-- is_archived = true on old rows — they never change is_active.
-- Partial unique indexes use WHERE is_active = true AND is_archived = false.
--
-- Online-safe: yes (< 1 second)

UPDATE table_documentation SET
  key_columns = '{"id": "uuid PK", "name": "text", "role": "text", "domain": "text", "content": "text - full soul markdown", "id_prefix": "text - A or S", "is_active": "boolean - business flag: enabled/disabled (NOT touched by versioning)", "activation": "text", "drive_mode": "text", "is_archived": "boolean - primary gate: true = historical/unused, false = alive (default false)", "trigger_type": "text", "responsibility": "text"}',
  notes = 'Append-only table. Never UPDATE in place — use save_soul_version() function. Versioning functions ONLY set is_archived=true on old rows; they NEVER change is_active. If a row is un-archived later, is_active retains its original business value. Read path: WHERE is_active=true AND is_archived=false. Partial unique indexes on (id_prefix) and (role) WHERE is_active=true AND is_archived=false.'
WHERE table_name = 'agent_souls';

UPDATE table_documentation SET
  key_columns = '{"id": "uuid PK", "job": "text - job description", "job_key": "text - stable slug per job (e.g. review.inter_review)", "soul_id": "uuid FK→agent_souls", "category": "text - job category", "priority": "int", "is_active": "boolean - business flag: enabled/disabled (NOT touched by versioning)", "created_at": "timestamptz", "updated_at": "timestamptz", "is_archived": "boolean - primary gate: true = historical/unused, false = alive (default false)"}',
  notes = 'Append-only table. Never UPDATE in place — use save_job_version() function. Versioning functions ONLY set is_archived=true on old rows; they NEVER change is_active. If a row is un-archived later, is_active retains its original business value. Read path: WHERE is_active=true AND is_archived=false. Partial unique index on (soul_id, job_key) WHERE is_active=true AND is_archived=false.'
WHERE table_name = 'agent_jobs';

-- ═══════════════════════════════════════════════════════════════════
-- Verification
-- ═══════════════════════════════════════════════════════════════════

SELECT table_name,
  CASE WHEN notes LIKE '%primary gate%' AND notes LIKE '%NEVER change is_active%' THEN 'OK' ELSE 'NEEDS FIX' END as status
FROM table_documentation WHERE table_name IN ('agent_souls', 'agent_jobs');
