# Database Migration Report: nezha → psypi

**Date**: 2026-05-03  
**Status**: Partially Complete  
**Approach**: Quality first - migrate compatible data, document differences

---

## Executive Summary

Migrated core data from nezha database to psypi database. Due to significant schema differences between the two databases, a selective migration approach was taken.

---

## Migration Results

### ✅ Successfully Migrated

| Table | Records | Notes |
|-------|---------|-------|
| **projects** | 1 | psypi project (0d324e68-b399-4b85-bd8a-6b1ef7b46168) |
| **skills** | 638 | All skills migrated with column mapping |
| **tasks** | 2 | Tasks for psypi project |
| **agent_identities** | 5/6 | 1 skipped (duplicate key) |

### ⚠️ Partially Migrated

| Table | Status | Notes |
|-------|--------|-------|
| **issues** | 0 migrated | No issues with direct project linkage found |
| **memory** | 0 migrated | No memory records for psypi project |
| **conversations** | 0 migrated | No conversations for psypi project |

### ❌ Skipped/Missing Tables

| Table | Reason |
|-------|--------|
| **meetings** | No project_id column; status constraint issues |
| **meeting_opinions** | Depends on meetings migration |
| **project_visits** | Table doesn't exist in psypi |
| **project_docs** | No data found for psypi project |
| **project_metrics** | No data found for psypi project |

---

## Schema Differences Documented

See [schema-differences-nezha-psypi.md](schema-differences-nezha-psypi.md) for detailed column-by-column comparison.

### Key Differences:
1. **projects**: psypi missing `fingerprint`, `type`, `last_seen` columns
2. **skills**: Different column sets (39 in nezha vs 53 in psypi)
3. **tasks**: psypi missing `metadata`, `template_id` (added during migration)
4. **issues**: psypi has no `project_id` column
5. **meetings**: psypi has different schema (8 columns vs more in nezha)
6. **agent_identities**: Uses `project` (varchar) not `project_id` (uuid)

---

## Migration Scripts Created

1. **scripts/migrate_skills.mjs** - Initial skills migration (superseded)
2. **scripts/migrate_all.mjs** - Projects + skills migration
3. **scripts/migrate_psypi_data.mjs** - Psypi-specific data migration

---

## Database Statistics (After Migration)

### psypi Database:
```sql
SELECT 'projects' as table_name, COUNT(*) FROM projects
UNION ALL
SELECT 'skills', COUNT(*) FROM skills
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks
UNION ALL
SELECT 'agent_identities', COUNT(*) FROM agent_identities;
```

Expected results:
- projects: 1
- skills: 638
- tasks: 2
- agent_identities: 5

---

## Next Steps

### Immediate:
1. ✅ Update `.env` to point to psypi database
2. ✅ Test psypi CLI commands
3. ✅ Verify application works with migrated data

### Future (if needed):
1. Migrate remaining tables with schema updates
2. Add missing columns to psypi tables
3. Re-run migration for issues, memory, etc.

---

## Backup Location

- nezha backup: `/tmp/psypi-migration-backup/nezha_20260503_*.sql`
- psypi backup: `/tmp/psypi-migration-backup/psypi_20260503_*.sql`

---

## Verification Commands

```bash
# Check psypi database
psql -U postgres -d psypi -c "SELECT COUNT(*) FROM skills;"
psql -U postgres -d psypi -c "SELECT * FROM projects;"
psql -U postgres -d psypi -c "SELECT * FROM tasks;"

# Test psypi CLI
cd /Users/jk/gits/hub/tools_ai/psypi
psypi status
psypi skill-list | head -20
```

---

## Lessons Learned

1. **Schema differences**: The psypi database evolved significantly from nezha
2. **Column mapping**: Careful column-by-column mapping is required
3. **Foreign key constraints**: Tables must be migrated in order
4. **Quality over completeness**: Better to migrate core data correctly than rush everything

---

**Report prepared by**: AI Agent (psypi)  
**Date**: 2026-05-03  
**Migration time**: ~2 hours (including debugging schema differences)
