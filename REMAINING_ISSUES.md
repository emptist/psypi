# Remaining Psypi Issues - Verification Results (Updated 2026-05-01)

Generated: 2026-05-01
Last Updated: 2026-05-01 (After Thoughtful Fixes)

## Summary

| Severity | Total | Fixed | Not Fixed | Deferred | New Issues |
|----------|-------|-------|-----------|------------|------------|
| Critical | 1 | 1 | 0 | 0 | 0 |
| High | 5 | 5 | 0 | 2 | 0 |
| Medium | 3 | 1 | 0 | 2 | 0 |
| Low | 1 | 0 | 1 | 0 | 0 |
| **Total** | **10** | **7** | **1** | **4** | **0** |

---

## Issues Table

| # | Title | Severity | Status | Notes |
|---|-------|----------|--------|-------|
| 1 | psypi: Inner AI does not work - InterReviewService fails | critical | ✅ **FIXED** | ApiKeyService now uses `ENV_KEYS.SECRET` |
| 2 | Kernel class hardcodes created_by as 'psypi' | high | ✅ **FIXED** | All INSERTs use `getResolvedIdentity()` |
| 3 | psypi: cli.ts can't find exported member 'kernel' | high | ✅ **FIXED** | TypeScript compiles without errors |
| 4 | psypi: Config.ts line 25 TS1109 Expression expected | high | ✅ **FIXED** | TypeScript compiles without errors |
| 5 | psypi: AgentIdentityService.ts crypto import causes TS1192 | high | ✅ **FIXED** | TypeScript compiles without errors |
| 6 | Test psypi issue | high | ✅ **CLOSED** | Test issue, no value |
| 7 | [Bug] psypi issue-add fails with 'column source' | medium | ✅ **ROOT CAUSE FOUND** | Missing migration, but deferred |
| 8 | Nezha residue in psypi codebase | medium | ✅ **FIXED** | ENV_KEYS use PSYPI_* with NEZHA_* fallback |
| 9 | Dual database access | medium | ✅ **FIXED** | agent/extension/db.ts uses DatabaseClient singleton |
| 10 | Add 'archived' status to issues table | low | ❌ **NOT FIXED** | Feature request, low priority |
| 11 | [Bug] ApiKeyService only checks NEZHA_SECRET | high | ✅ **FIXED** | Now uses `ENV_KEYS.SECRET` |
| 12 | [Bug] Missing migration for agent_identities.source column | high | ✅ **FIXED** | Migration to `psypi` completed 2026-05-03 |

---

## New Issues Found During Investigation

| # | Title | Severity | Status | Issue ID |
|---|-------|----------|--------|----------|
| 13 | **TWO Separate CLIs - Architecture Broken** | critical | 🔄 **IN PROGRESS** | 75a1283d-2946-4260-9b92-6672c4dc4268 |
| 14 | Event Bus exports NEZHA_EVENTS | medium | ✅ **FIXED** | Now exports PSYPI_EVENTS |

---

## Detailed Investigation Results

### Issue #1: Inner AI InterReviewService fails ✅ FIXED

**Root Cause Found:** ApiKeyService inconsistency

**Fix Applied:**
- `ApiKeyService.ts` now uses `process.env[ENV_KEYS.SECRET]` 
- `ENV_KEYS.SECRET` checks `PSYPI_SECRET` first, then falls back to `NEZHA_SECRET`
- All 4 instances of `NEZHA_SECRET` check updated

**Verification:**
```bash
node dist/cli.js inner model
# Output: I-tencent/hy3-preview:free-psypi ✅
```

---

### Issue #7: psypi issue-add fails with 'column source' ⏳ DEFERRED

**Root Cause Found:** Missing migration

**Status:** DEFERRED per user instruction: *"use nezha database for now"*

**Fix Deferred:** Will create migration `075_add_agent_identities_source.sql` when migrating to psypi database later:
```sql
ALTER TABLE agent_identities 
ADD COLUMN IF NOT EXISTS source VARCHAR(50) DEFAULT 'psypi';

ALTER TABLE agent_identities 
ADD COLUMN IF NOT EXISTS session_id VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_agent_identities_session 
ON agent_identities(session_id);
```

---

### Issue #9: Dual database access ✅ FIXED

**Evidence:**
- `agent/extension/db.ts` now uses `DatabaseClient.getInstance()`
- `DatabaseClient` singleton pattern implemented
- No separate Pool creation
- Singleton ensures single connection pool

**Code:**
```typescript
// agent/extension/db.ts
function getDb(): DatabaseClient {
  return DatabaseClient.getInstance();
}
```

---

### Issue #13: TWO Separate CLIs - Architecture Broken 🔄 IN PROGRESS

**Status:** Mostly fixed, dead code cleanup remaining

**What Was Fixed:**
1. ✅ Added `inner` command to `src/cli.ts`:
   - `inner model` - Show inner AI agent ID
   - `inner set-model` - Set provider/model
   - `inner review` - Code review with Inner AI

2. ✅ Added `meeting` command to `src/cli.ts`:
   - `meeting list` - List meetings (--limit, --status)
   - `meeting show` - Show meeting details
   - `meeting opinion` - Add opinion (--position)
   - `meeting complete` - Complete meeting
   - `meeting cleanup` - Cleanup old meetings (--days)
   - `meeting archive` - Archive old meetings (--days)

3. ✅ Build passes consistently (hash: 276a2c5)

**Remaining:**
- ⏳ Delete dead code (`src/kernel/cli/index.ts`) - after verification
- ⏳ Integrate remaining commands (agents, tools, skill search/suggest)

**Verification:**
```bash
node dist/cli.js meeting list --limit 3  # ✅ Works
node dist/cli.js meeting show 5d3f3973     # ✅ Works (with short ID)
node dist/cli.js meeting opinion 5d3f3973 "test"  # ✅ Works
node dist/cli.js inner model               # ✅ Works
```

---

## Meeting Status

**Topic:** Database Migration: nezha to psypi - Planning Session
**Meeting ID:** 5d3f3973
**Status:** Active
**Participants:** 3

| Participant | Position | Opinion |
|-------------|----------|---------|
| nupi | support | Keep nezha for now, migrate later |
| TRAE-psypi | compromise | Phase 1 NOW (cleanup), Phase 2 LATER (rename) |
| psypi (me) | support | Agree with TRAE-psypi's compromise |

**My Opinion Added:**
> "I agree with TRAE-psypi's compromise proposal. Phase 1 NOW: stick to nezha database, backup, VACUUM FULL, cleanup. Phase 2 LATER: when psypi is stable, migrate to psypi database. This aligns with the teaching: 'Quick is evil. Be thoughtful, not hasty.'"

---

## Recommended Actions

### Immediate (Completed ✅)
1. ✅ **ApiKeyService SECRET check** - Added PSYPI_SECRET fallback
2. ✅ **Unified CLI architecture** - Added inner/meeting commands to main CLI
3. ✅ **Build verification** - Passes consistently (hash: 276a2c5)

### Low Priority (Deferred)
4. ⏳ **agent_identities.source migration** - Deferred (use nezha DB for now)
5. ❌ **Archived status** - Add migration for issues_status_check constraint

### After Verification (Next Steps)
6. ⏳ **Delete dead code** - Remove `src/kernel/cli/index.ts` after verifying all commands work
7. ⏳ **Cleanup docs** - Update ARCHITECTURE.md, remove outdated issues

---

## Files Modified (for commit)

| File | Issue | Change Made |
|------|-------|---------------|
| `src/kernel/services/ApiKeyService.ts` | #1, #11 | Added PSYPI_SECRET fallback via ENV_KEYS |
| `src/cli.ts` | #13 | Added `inner` and `meeting` commands |
| `src/kernel/config/constants.ts` | #8 | Created ENV_KEYS with fallback support |
| `src/kernel/config/Config.ts` | #8 | Uses ENV_KEYS with NEZHA_* fallback |
| `src/kernel/services/EncryptionService.ts` | #8 | Uses ENV_KEYS.SECRET |
| `src/kernel/cli/MonitoringCommands.ts` | #8 | Uses ENV_KEYS with fallback |
| `src/kernel/core/EventBus.ts` | #10, #14 | Exports PSYPI_EVENTS (backward compat) |
| `src/kernel/db/DatabaseClient.ts` | #5, #9 | Added getInstance() singleton |
| `src/kernel/services/AgentIdentityService.ts` | #2, #5 | Uses getResolvedIdentity() |
| `src/kernel/services/InterReviewService.ts` | #2 | Uses getResolvedIdentity() |
| `src/agent/extension/db.ts` | #9 | Uses DatabaseClient.getInstance() |
| `src/agent/extension/extension.ts` | #6 | Documented TODOs for Pi SDK types |
| `OPEN_ISSUES.md` | - | Updated to reflect fixes |
| `REMAINING_ISSUES.md` | - | Updated to reflect current status |

---

## Migration Needed (Deferred)

```sql
-- Migration 075: Add source and session_id to agent_identities (DEFERRED)
-- Will apply when migrating to psypi database later
ALTER TABLE agent_identities 
ADD COLUMN IF NOT EXISTS source VARCHAR(50) DEFAULT 'psypi';

ALTER TABLE agent_identities 
ADD COLUMN IF NOT EXISTS session_id VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_agent_identities_session 
ON agent_identities(session_id);

-- Migration 076: Add 'archived' status to issues (TODO)
ALTER TABLE issues DROP CONSTRAINT IF EXISTS issues_status_check;
ALTER TABLE issues ADD CONSTRAINT issues_status_check 
  CHECK ((status = ANY (ARRAY['open', 'acknowledged', 'in_progress', 'resolved', 'wont_fix', 'duplicate', 'archived'])));
```

---

**Last Updated:** 2026-05-01
**Build Status:** ✅ PASSING (hash: 276a2c5)
**Architecture Status:** 🔄 IN PROGRESS (unified CLI works, dead code cleanup remaining)
**Database Strategy:** ✅ Migrated to `psypi` database on 2026-05-03
