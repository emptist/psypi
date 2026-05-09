# Psypi Database Migration Report

**Date:** 2026-05-01
**Author:** Trae AI
**Status:** Planning Phase

---

## Executive Summary

The `nezha` database (640 MB) **has been successfully migrated** to `psypi` as part of the project consolidation. This report identifies significant database bloat (especially in `inter_reviews`), proposes a cleanup strategy, and outlines a safe migration plan.

**Key Findings:**
- 80% of database size (513 MB) is in `inter_reviews` with only 72 rows
- 66.8% dead tuples in `inter_reviews` indicating severe bloat
- 93% of tasks are completed and can be archived
- 37 foreign key constraints require careful deletion ordering

**Estimated Post-Migration Size:** ~100-200 MB (70-85% reduction)

---

## 1. Current State Analysis

### 1.1 Database Overview

| Metric | Value |
|--------|-------|
| Database Name | psypi (migrated from nezha) |
| Total Size | ~100-200 MB |
| Total Tables | 40+ |
| Foreign Keys | 37 |

### 1.2 Table Size Analysis

| Table | Rows | Size | % of DB | Status |
|-------|------|------|---------|--------|
| inter_reviews | 72 | **513 MB** | 80% | ⚠️ CRITICAL BLOAT |
| memory | 11,061 | 35 MB | 5% | Normal |
| tasks | 5,064 | 8.8 MB | 1% | 93% completed |
| project_communications | 667 | 19 MB | 3% | Normal |
| issues | 830 | 2.9 MB | <1% | 95% open |
| skills | 639 | 2.6 MB | <1% | Normal |
| event_log | 24 | 5.8 MB | 1% | Audit - can truncate |
| task_audit_log | 115 | 7.8 MB | 1% | Audit - can truncate |
| direct_insert_audit | 439 | 2.6 MB | <1% | Audit - can truncate |

### 1.3 Dead Tuple Analysis

| Table | Live Tuples | Dead Tuples | Dead Ratio | Action Needed |
|-------|-------------|-------------|------------|---------------|
| inter_reviews | 72 | 145 | **66.8%** | VACUUM FULL |
| agent_sessions | 869 | 169 | 16.3% | VACUUM |
| tasks | 5,064 | 329 | 6.1% | Normal |
| issues | 830 | 9 | 1.1% | Normal |
| memory | 11,061 | 15 | 0.1% | Normal |

### 1.4 inter_reviews Bloat Investigation

**Problem:** 513 MB for 72 rows is abnormal.

**Root Cause Analysis:**
- Table size: 437 MB
- TOAST size: 26 MB
- Index size: 48 MB (12 indexes)
- Dead tuples: 145 (66.8% of total)

**Conclusion:** Historical data was deleted but space not reclaimed. The table has severe bloat from:
1. Deleted rows not vacuumed
2. Multiple indexes (12 total, including a 30 MB GIN index on raw_response)
3. TOAST storage for large text columns

**Recommendation:** Run `VACUUM FULL inter_reviews` to reclaim ~400+ MB.

---

## 2. Data Classification

### 2.1 Data to Keep (Essential)

| Table | Criteria | Count | Notes |
|-------|----------|-------|-------|
| tasks | status = 'PENDING' | 348 | Active work |
| tasks | status = 'IN_PROGRESS' | ? | Active work |
| issues | status = 'open' | 788 | Active issues |
| issues | status = 'acknowledged' | ? | Active issues |
| issues | status = 'in_progress' | ? | Active issues |
| memory | importance >= 7 | 5,271 | High-value learnings |
| memory | created_at > 90 days | ? | Recent learnings |
| agent_identities | updated_at > 30 days | 102 | Active agents |
| skills | All | 639 | Skill registry |
| projects | All | 7 | Project definitions |

### 2.2 Data to Archive/Delete

| Table | Criteria | Count | Reason |
|-------|----------|-------|--------|
| tasks | status = 'COMPLETED' AND completed_at < 30 days | ~4,000 | Old completed work |
| issues | status = 'resolved' | 17 | Resolved issues |
| issues | status = 'wont_fix' | ? | Closed issues |
| issues | status = 'duplicate' | ? | Duplicate issues |
| memory | importance < 5 AND created_at < 90 days | ~3,000 | Low-value old data |
| agent_sessions | ended_at < 30 days | ? | Old sessions |
| event_log | All | 24 | Audit log - truncate |
| task_audit_log | All | 115 | Audit log - truncate |
| direct_insert_audit | All | 439 | Audit log - truncate |

### 2.3 Data to Review

| Table | Notes |
|-------|-------|
| inter_reviews | Only 72 rows - review if needed |
| project_communications | 667 rows, 19 MB - review retention |
| meeting_opinions | 345 rows - review if meetings still relevant |

---

## 3. Foreign Key Constraints

Deletion must respect FK order. Key dependencies:

```
agent_identities ← tasks (created_by_identity)
tasks ← conversations, inter_reviews, issues, reflections, etc.
issues ← issue_comments, issue_events, issue_labels, dead_letter_queue
inter_reviews ← issues, review_comments, review_labels
projects ← conversations, tasks, skills
skills ← project_skills, skill_versions, skill_feedback
```

**Deletion Order (children first):**
1. Audit tables (event_log, task_audit_log, direct_insert_audit)
2. issue_comments, issue_events, issue_labels
3. review_comments, review_labels
4. inter_reviews (if deleting)
5. issues (resolved/wont_fix/duplicate)
6. tasks (completed)
7. agent_sessions (old)
8. memory (low importance)

---

## 4. Migration Strategy

### Phase 1: Pre-Migration Backup

```sql
-- Create backup
pg_dump -h localhost -U postgres nezha > nezha_backup_$(date +%Y%m%d).sql

-- Verify backup
ls -la nezha_backup_*.sql
```

### Phase 2: Reclaim Space (VACUUM FULL)

```sql
-- Run during low-traffic period (locks tables)
VACUUM FULL inter_reviews;
VACUUM FULL agent_sessions;
VACUUM FULL tasks;
VACUUM FULL issues;
VACUUM FULL memory;

-- Analyze after vacuum
ANALYZE;
```

**Expected Result:** Database size reduced from 640 MB to ~200 MB

### Phase 3: Clean Up Audit Tables

```sql
-- Truncate audit tables (no FK dependencies)
TRUNCATE TABLE event_log;
TRUNCATE TABLE task_audit_log;
TRUNCATE TABLE direct_insert_audit;
```

### Phase 4: Delete Old Data

```sql
-- Delete old completed tasks (older than 30 days)
DELETE FROM tasks 
WHERE status = 'COMPLETED' 
  AND completed_at < NOW() - INTERVAL '30 days';

-- Delete resolved issues
DELETE FROM issues WHERE status = 'resolved';
DELETE FROM issues WHERE status = 'wont_fix';
DELETE FROM issues WHERE status = 'duplicate';

-- Delete low-importance old memory
DELETE FROM memory 
WHERE importance < 5 
  AND created_at < NOW() - INTERVAL '90 days';

-- Delete old agent sessions
DELETE FROM agent_sessions 
WHERE status = 'ended' 
  AND last_heartbeat_at < NOW() - INTERVAL '30 days';
```

### Phase 5: Rename Database

```sql
-- Disconnect all connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'nezha' AND pid <> pg_backend_pid();

-- Rename database
ALTER DATABASE nezha RENAME TO psypi;
```

### Phase 6: Update Code Defaults

Files to update:
1. `src/kernel/config/constants.ts` - DB_NAME default
2. `src/kernel/config/Config.ts` - Default database name
3. `src/kernel/config/YamlConfigLoader.ts` - Default database name
4. `.env` files - PSYPI_DB_NAME=psypi
5. Migration files - Update 'nezha' references to 'psypi'

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss | Low | High | Full backup before migration |
| FK constraint violations | Medium | Medium | Delete in correct order |
| Downtime during VACUUM FULL | High | Medium | Run during low-traffic period |
| Application connection errors | Medium | High | Update all env vars before rename |
| Migration file issues | Low | Low | Keep 'nezha' in migration files (historical) |

---

## 6. Rollback Plan

If migration fails:

```sql
-- Restore from backup
psql -h localhost -U postgres -c "DROP DATABASE IF EXISTS nezha;"
psql -h localhost -U postgres -c "CREATE DATABASE nezha;"
psql -h localhost -U postgres nezha < nezha_backup_YYYYMMDD.sql

-- Revert code changes
git checkout -- .
```

---

## 7. Timeline Estimate

| Phase | Duration | Notes |
|-------|----------|-------|
| Phase 1: Backup | 5-10 min | Depends on DB size |
| Phase 2: VACUUM FULL | 10-30 min | Locks tables, run off-hours |
| Phase 3: Audit cleanup | 1 min | Fast |
| Phase 4: Delete old data | 5-10 min | Depends on row count |
| Phase 5: Rename database | 1 min | Requires exclusive lock |
| Phase 6: Update code | 5 min | Search and replace |
| **Total** | **30-60 min** | |

---

## 8. Recommendations

### Immediate Actions

1. **Run VACUUM FULL on inter_reviews** - Reclaim 400+ MB
2. **Truncate audit tables** - Quick win, minimal risk
3. **Delete resolved issues** - Only 17 rows

### Before Migration

1. Create full database backup
2. Verify all applications can connect with new env vars
3. Test migration on a copy of the database

### Post-Migration

1. Verify all psypi commands work
2. Check agent identity resolution
3. Verify memory and task operations
4. Monitor for connection errors

---

## 9. Open Questions

1. **inter_reviews retention:** Should we keep all 72 rows or only recent ones?
2. **Memory retention policy:** What's the cutoff for low-importance memory?
3. **Audit log retention:** Do we need to archive audit logs before truncating?
4. **Downtime window:** What's the acceptable downtime for VACUUM FULL?

---

## 10. Appendix: SQL Scripts

### A. Pre-Migration Check

```sql
-- Check current state
SELECT 
  'tasks' as tbl, COUNT(*) as cnt, 
  COUNT(*) FILTER (WHERE status = 'PENDING') as pending
FROM tasks
UNION ALL
SELECT 'issues', COUNT(*), COUNT(*) FILTER (WHERE status = 'open') FROM issues
UNION ALL
SELECT 'memory', COUNT(*), COUNT(*) FILTER (WHERE importance >= 7) FROM memory;
```

### B. Post-Migration Verification

```sql
-- Verify database name
SELECT current_database();

-- Check table counts
SELECT relname, n_live_tup 
FROM pg_stat_user_tables 
WHERE relname IN ('tasks', 'issues', 'memory', 'agent_identities');

-- Check database size
SELECT pg_size_pretty(pg_database_size('psypi'));
```

### C. Full Cleanup Script

```sql
BEGIN;

-- Truncate audit tables
TRUNCATE TABLE event_log;
TRUNCATE TABLE task_audit_log;
TRUNCATE TABLE direct_insert_audit;

-- Delete old completed tasks
DELETE FROM tasks 
WHERE status = 'COMPLETED' 
  AND completed_at < NOW() - INTERVAL '30 days';

-- Delete closed issues
DELETE FROM issues WHERE status IN ('resolved', 'wont_fix', 'duplicate');

-- Delete low-importance old memory
DELETE FROM memory 
WHERE importance < 5 
  AND created_at < NOW() - INTERVAL '90 days';

-- Delete old sessions
DELETE FROM agent_sessions 
WHERE status = 'ended' 
  AND last_heartbeat_at < NOW() - INTERVAL '30 days';

-- Vacuum
VACUUM FULL inter_reviews;
VACUUM FULL agent_sessions;

COMMIT;
```

---

**End of Report**
