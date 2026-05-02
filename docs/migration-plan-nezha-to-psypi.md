# Migration Plan: Nezha Database to PsyPI Database

**Date**: 2026-05-03  
**Status**: Draft - Ready for Review  
**Priority**: High  

---

## Executive Summary

Migrate data from the legacy `nezha` database to the new `psypi` database, preserving table structures while transferring only psypi-specific data and all skills.

**Source**: `nezha` database (79 tables, 638 skills, 7 projects)  
**Target**: `psypi` database (53 tables, 0 skills, 0 projects)  
**Psypi Project ID**: `0d324e68-b399-4b85-bd8a-6b1ef7b46168`

---

## 1. Migration Scope

### 1.1 Data to Migrate

#### A. All Skills (Unconditional)
- **Table**: `skills`
- **Count**: 638 skills
- **Reason**: Skills are global assets, not project-specific

#### B. Psypi-Specific Data (Project ID: 0d324e68-b399-4b85-bd8a-6b1ef7b46168)
All data tagged with or related to the psypi project:

**Core Tables:**
- `projects` - Psypi project record
- `tasks` - Tasks belonging to psypi project
- `issues` - Issues belonging to psypi project
- `memory` - Memories created under psypi project
- `meetings` + `meeting_opinions` - Meeting records for psypi

**Supporting Tables:**
- `agent_identities` - Agent identities created under psypi
- `agent_sessions` - Sessions for psypi project
- `conversations` - Conversations under psypi
- `inter_reviews` - Review records for psypi
- `reflections` - Reflection records
- `project_visits` - Visit records for psypi
- `project_docs` - Documentation for psypi
- `project_metrics` - Metrics for psypi
- `project_skills` - Skills assigned to psypi project
- `scheduled_tasks` - Scheduled tasks for psypi

**Audit & Logging:**
- `activity_log` - Activity under psypi project
- `event_log` - Events for psypi
- `task_audit_log` - Task audit entries
- `issue_events` - Issue events
- `direct_insert_audit` - Audit records

### 1.2 Data NOT to Migrate

- Data from other projects (nezha-core, nupi, tools_ai, two_way_comm, piano, nezha)
- Legacy tables not present in psypi schema:
  - `agent_configs`, `agent_moods`, `agent_soul`
  - `memories` (old table, replaced by `memory`)
  - `failure_alerts`, `failure_statistics`, `failure_trend_analysis`
  - `heartbeat_configs`
  - `insight_summary`, `learning_insights`, `priority_learnings`
  - `milestones`, `milestone_progress`
  - `orphaned_processes_summary`, `stuck_tasks_tracking`
  - `pending_inter_reviews`, `pending_system_reviews`
  - `process_pids` (may need review)
  - `provider_api_keys`
  - `psypi_config` (old config table)
  - `recent_issues`, `issues_by_severity`, `issue_stats`, `issue_timeline`
  - `retry_learning`, `retry_strategies`
  - `review_comments`, `review_labels`
  - `skill_audit_log`, `skill_builder_config`, `skill_feedback`, `skill_versions`
  - `souls` (old table)
  - `task_comments`, `task_outcome_features`, `task_patterns`, `task_results`
  - `tool_definitions`
  - `user_profiles`
  - `v_direct_insert_violations`, `v_table_documentation` (views)
  - `test_uuid_col`

---

## 2. Pre-Migration Analysis

### 2.1 Schema Differences

| Aspect | Nezha DB | Psypi DB | Action |
|--------|----------|----------|--------|
| Table count | 79 tables | 53 tables | Migrate only common tables |
| Skills table | ✓ | ✓ | Full migration |
| Projects table | 7 records | 0 records | Migrate psypi only |
| New tables in psypi | - | `email_verifications`, `password_resets`, `payments`, etc. | Keep empty |

### 2.2 Data Volume Estimation

```sql
-- Estimated row counts for psypi project (run in nezha DB)
SELECT 'tasks' as table_name, COUNT(*) as count FROM tasks WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'
UNION ALL
SELECT 'issues', COUNT(*) FROM issues WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'
UNION ALL
SELECT 'memory', COUNT(*) FROM memory WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'
UNION ALL
SELECT 'skills', COUNT(*) FROM skills;
```

### 2.3 Foreign Key Dependencies

**Critical dependency order:**
1. `projects` → `agent_identities` → `agent_sessions`
2. `projects` → `tasks` → `task_audit_log`, `scheduled_tasks`
3. `projects` → `issues` → `issue_events`, `issue_labels`, `issue_comments`
4. `projects` → `meetings` → `meeting_opinions`
5. `projects` → `memory` → `knowledge_links`
6. `projects` → `project_visits`, `project_docs`, `project_metrics`, `project_skills`
7. `skills` (independent, migrate first or last)

---

## 3. Migration Steps

### Phase 1: Preparation (Dry Run)

```bash
# 1. Backup both databases
pg_dump nezha > /backup/nezha_$(date +%Y%m%d).sql
pg_dump psypi > /backup/psypi_$(date +%Y%m%d).sql

# 2. Create migration tracking table in psypi
psql psypi -c "
CREATE TABLE IF NOT EXISTS migration_log (
  id SERIAL PRIMARY KEY,
  table_name VARCHAR(100),
  records_migrated INTEGER,
  started_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  status VARCHAR(20) DEFAULT 'pending',
  error_message TEXT
);"
```

### Phase 2: Schema Alignment

```sql
-- Ensure psypi DB has all required tables
-- (Run any missing migrations from /src/kernel/db/migrations/)
```

### Phase 3: Data Migration (Ordered)

#### Step 1: Migrate Skills (Global)
```sql
-- Export from nezha
\copy skills TO '/tmp/skills.csv' CSV HEADER;

-- Import to psypi
\copy skills FROM '/tmp/skills.csv' CSV HEADER;
```

#### Step 2: Migrate Projects (Psypi Only)
```sql
INSERT INTO psypi.projects 
SELECT * FROM nezha.projects 
WHERE id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 3: Migrate Agent Identities & Sessions
```sql
-- Agent identities for psypi project
INSERT INTO psypi.agent_identities 
SELECT * FROM nezha.agent_identities 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Agent sessions for psypi project
INSERT INTO psypi.agent_sessions 
SELECT * FROM nezha.agent_sessions 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 4: Migrate Tasks & Related
```sql
-- Tasks
INSERT INTO psypi.tasks 
SELECT * FROM nezha.tasks 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Task audit log
INSERT INTO psypi.task_audit_log 
SELECT tal.* FROM nezha.task_audit_log tal
JOIN nezha.tasks t ON tal.task_id = t.id
WHERE t.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Scheduled tasks
INSERT INTO psypi.scheduled_tasks 
SELECT st.* FROM nezha.scheduled_tasks st
JOIN nezha.tasks t ON st.task_id = t.id
WHERE t.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 5: Migrate Issues & Related
```sql
-- Issues
INSERT INTO psypi.issues 
SELECT * FROM nezha.issues 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Issue events
INSERT INTO psypi.issue_events 
SELECT ie.* FROM nezha.issue_events ie
JOIN nezha.issues i ON ie.issue_id = i.id
WHERE i.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Issue labels (if using issue_id)
INSERT INTO psypi.issue_labels 
SELECT il.* FROM nezha.issue_labels il
JOIN nezha.issues i ON il.issue_id = i.id
WHERE i.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Issue comments
INSERT INTO psypi.issue_comments 
SELECT ic.* FROM nezha.issue_comments ic
JOIN nezha.issues i ON ic.issue_id = i.id
WHERE i.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 6: Migrate Memory & Knowledge
```sql
-- Memory
INSERT INTO psypi.memory 
SELECT * FROM nezha.memory 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Knowledge links (only if both memories are in psypi)
INSERT INTO psypi.knowledge_links 
SELECT kl.* FROM nezha.knowledge_links kl
JOIN nezha.memory m1 ON kl.from_id = m1.id
JOIN nezha.memory m2 ON kl.to_id = m2.id
WHERE m1.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'
  AND m2.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 7: Migrate Meetings
```sql
-- Meetings for psypi project
INSERT INTO psypi.meetings 
SELECT * FROM nezha.meetings 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Meeting opinions
INSERT INTO psypi.meeting_opinions 
SELECT mo.* FROM nezha.meeting_opinions mo
JOIN nezha.meetings m ON mo.meeting_id = m.id
WHERE m.project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 8: Migrate Project-Specific Tables
```sql
-- Project visits
INSERT INTO psypi.project_visits 
SELECT * FROM nezha.project_visits 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Project docs
INSERT INTO psypi.project_docs 
SELECT * FROM nezha.project_docs 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Project metrics
INSERT INTO psypi.project_metrics 
SELECT * FROM nezha.project_metrics 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Project skills
INSERT INTO psypi.project_skills 
SELECT * FROM nezha.project_skills 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 9: Migrate Conversations & Reviews
```sql
-- Conversations
INSERT INTO psypi.conversations 
SELECT * FROM nezha.conversations 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Inter reviews
INSERT INTO psypi.inter_reviews 
SELECT * FROM nezha.inter_reviews 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 10: Migrate Activity & Events
```sql
-- Activity log
INSERT INTO psypi.activity_log 
SELECT * FROM nezha.activity_log 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Event log
INSERT INTO psypi.event_log 
SELECT * FROM nezha.event_log 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 11: Migrate Supporting Tables
```sql
-- Reflections
INSERT INTO psypi.reflections 
SELECT * FROM nezha.reflections 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Task templates (if project-specific)
INSERT INTO psypi.task_templates 
SELECT * FROM nezha.task_templates 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';

-- Reminder templates (if project-specific)
INSERT INTO psypi.reminder_templates 
SELECT * FROM nezha.reminder_templates 
WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168';
```

#### Step 12: Update Table Documentation
```sql
-- Migrate table documentation
INSERT INTO psypi.table_documentation 
SELECT * FROM nezha.table_documentation 
ON CONFLICT (table_name) DO UPDATE SET
  purpose = EXCLUDED.purpose,
  usage_context = EXCLUDED.usage_context,
  key_columns = EXCLUDED.key_columns,
  related_tables = EXCLUDED.related_tables,
  notes = EXCLUDED.notes,
  updated_at = NOW();
```

### Phase 4: Validation

```sql
-- Validate record counts match
SELECT 'projects' as table_name, 
  (SELECT COUNT(*) FROM nezha.projects WHERE id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168') as nezha_count,
  (SELECT COUNT(*) FROM psypi.projects WHERE id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168') as psypi_count
UNION ALL
SELECT 'tasks', 
  (SELECT COUNT(*) FROM nezha.tasks WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'),
  (SELECT COUNT(*) FROM psypi.tasks WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168')
UNION ALL
SELECT 'issues',
  (SELECT COUNT(*) FROM nezha.issues WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168'),
  (SELECT COUNT(*) FROM psypi.issues WHERE project_id = '0d324e68-b399-4b85-bd8a-6b1ef7b46168')
UNION ALL
SELECT 'skills', (SELECT COUNT(*) FROM nezha.skills), (SELECT COUNT(*) FROM psypi.skills);
```

### Phase 5: Update Configuration

```bash
# Update .env to point to psypi database
sed -i '' 's/DATABASE_URL=.*/DATABASE_URL=postgresql:\/\/postgres:postgres@localhost:5432\/psypi/' .env
```

---

## 4. Rollback Plan

```sql
-- If migration fails, clear psypi database tables
TRUNCATE skills CASCADE;
TRUNCATE projects CASCADE;
-- ... (other tables)

-- Or restore from backup
dropdb psypi && createdb psypi
psql psypi < /backup/psypi_YYYYMMDD.sql
```

---

## 5. Success Criteria

- [ ] All 638 skills migrated to psypi
- [ ] Psypi project record exists in psypi DB
- [ ] All psypi-specific tasks, issues, memories migrated
- [ ] All foreign key relationships intact
- [ ] No data from other projects leaked
- [ ] Table documentation updated
- [ ] Application connects successfully to psypi DB
- [ ] All psypi CLI commands work with new DB

---

## 6. Timeline

| Phase | Description | Estimated Time |
|-------|-------------|----------------|
| 1 | Backup & Preparation | 10 min |
| 2 | Schema Alignment | 15 min |
| 3 | Data Migration | 30 min |
| 4 | Validation | 15 min |
| 5 | Config Update & Testing | 10 min |
| **Total** | | **~80 min** |

---

## 7. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Foreign key violations | High | Migrate in correct order, validate dependencies |
| Data type mismatches | Medium | Run schema comparison before migration |
| Missing tables in psypi | Medium | Create missing tables or skip data |
| Session/Identity conflicts | Low | Clear conflicting records first |
| Disk space for CSV exports | Low | Use temp directory, clean up after |

---

## 8. Post-Migration Tasks

1. Update `DATABASE_URL` in `.env` to point to `psypi` database
2. Run `pnpm build` to verify compilation
3. Test psypi CLI commands:
   - `psypi status`
   - `psypi skill-list`
   - `psypi tasks`
   - `psypi project`
4. Update AGENTS.md to reflect new database
5. Commit changes with `psypi commit`

---

## 9. Approval Required

- [ ] Review migration plan
- [ ] Approve data scope (psypi-only + skills)
- [ ] Confirm backup strategy
- [ ] Sign-off to proceed

---

**Prepared by**: AI Agent (psypi)  
**Next step**: Report issue with this plan for tracking, then execute migration
