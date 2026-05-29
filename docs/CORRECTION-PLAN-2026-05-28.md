# psypi Correction Plan — 2026-05-28

Based on verification review (ab6e34f0) of trae-ai's original review (ca9e914c).
24 verified findings. 3 root cause categories. Prioritized fix order.

## ROOT CAUSE 1: FFI Bridge Broken (JS/Gleam Type Mismatch)

### Fix 1.1: pi_extension_ffi.mjs get_config/set_config — CRITICAL
**File:** `src/pi_extension_ffi.mjs`
**Problem:** `get_config` returns JS `null` or raw JS string. Gleam expects `option.None` or `option.Some(String)`.
**Fix:** Wrap return values in proper Gleam constructors:
```javascript
export function get_config(key) {
  const val = _configStore[key];
  if (val === undefined || val === null) {
    return new None();  // Gleam None constructor
  }
  return new Some(String(val));  // Gleam Some constructor
}
```
**Impact:** Fixes A-bot debounce chain. Without this, A-bot is completely dead.

### Fix 1.2: pi_extension_ffi.mjs gleamValueToJson — MEDIUM
**File:** `src/pi_extension_ffi.mjs`
**Problem:** Hardcoded type name list misses EnrichedIdentity, HealthMetrics, ReviewFinding, SystemReview.
**Fix:** Add missing type names to the `name.startsWith()` check list, or use a more generic approach:
```javascript
// Add to the chain:
name.startsWith('EnrichedIdentity$EnrichedIdentity') ||
name.startsWith('HealthMetrics$HealthMetrics') ||
name.startsWith('ReviewFinding$ReviewFinding') ||
name.startsWith('SystemReview$SystemReview') ||
name.startsWith('Finding$Finding')
```

### Fix 1.3: pi_extension_ffi.mjs unwrapGleamResult — LOW
**File:** `src/pi_extension_ffi.mjs`
**Problem:** Checks `result.constructor?.name` which may not match all Gleam Result shapes.
**Fix:** Use `result instanceof Ok` / `result instanceof Error` if available, or check for `['0']` field presence.

---

## ROOT CAUSE 2: Systematic Missing ::text Casts

### Fix 2.1: Add ::text casts to ALL uuid/timestamptz columns in SELECT — HIGH
**Pattern:** Every SELECT that returns uuid or timestamptz columns needs `::text` cast.
**Affected files and queries:**

| File | Query | Columns to cast |
|------|-------|-----------------|
| `agent_identity.gleam` | fetch_soul_by_prefix | `id::text` |
| `meeting.gleam` | all SELECTs | `id::text` |
| `agents.gleam` | list | `id::text` |
| `monitor.gleam` | get_pending_notifications | `id::text` |
| `task.gleam` | list, get | `id::text` |
| `issue_db.gleam` | list, get | `id::text` |
| `code_version.gleam` | save_version | `version_id::text` (from function return) |
| `code_version.gleam` | query_versions | `id::text, saved_at::text` |
| `code_version.gleam` | get_versions | `id::text, saved_at::text` (from function return) |
| `areflect.gleam` | fetch_recent_issues | `id::text` |
| `broadcast.gleam` | list, get_recent | `id::text` |
| `inter_review.gleam` | get_review_details, list_reviews | `id::text, task_id::text, requested_at::text` |
| `inter_review.gleam` | request_review | `review_id::text` (from function return) |
| `stats.gleam` | all COUNT(*) | `COUNT(*)::text` |
| `a_db_reader.gleam` | is_s_still_idle | `COUNT(*)::int` |

**Fix pattern:** Change `SELECT id, ...` to `SELECT id::text, ...` and `SELECT * FROM func()` to `SELECT id::text, col2, ...`

---

## ROOT CAUSE 3: Gleam Type vs DB CHECK Constraint Mismatch

### Fix 3.1: IssueStatus — HIGH
**File:** `src/issue_types.gleam`
**Problem:** Gleam has `Open, InProgress, Resolved, Closed`. DB has `open, acknowledged, in_progress, resolved, wont_fix, duplicate`.
**Fix:**
```gleam
pub type IssueStatus {
  Open
  Acknowledged
  InProgress
  Resolved
  WontFix
  Duplicate
}
```
Update `string_to_status()` to handle all 6 DB values. Remove `Closed`.

### Fix 3.2: TaskStatus — MEDIUM
**File:** `src/task.gleam`
**Problem:** Missing `FakeComplete` variant.
**Fix:**
```gleam
pub type TaskStatus {
  Pending
  Running
  Completed
  Failed
  FakeComplete
}
```
Update `string_to_status()` to handle `FAKE_COMPLETE`.

### Fix 3.3: SkillSource — MEDIUM
**File:** `src/skill.gleam`
**Problem:** Missing `AiBuilt` variant.
**Fix:**
```gleam
pub type SkillSource {
  Clawhub
  Local
  Generated
  Imported
  AiBuilt
}
```

### Fix 3.4: MeetingStatus — MEDIUM
**File:** `src/meeting.gleam`
**Problem:** Has `Pending` but DB doesn't allow it.
**Fix:** Remove `Pending` variant:
```gleam
pub type MeetingStatus {
  Active
  Completed
  Cancelled
}
```

### Fix 3.5: IssueType — LOW
**File:** `src/issue_types.gleam`
**Problem:** Missing `Proposal` variant.
**Fix:**
```gleam
pub type IssueType {
  Bug
  Inconsistency
  Feature
  Improvement
  Question
  Debt
  Proposal
}
```

---

## PRIORITY FIX ORDER (Do NOT implement until ordered)

### Phase 1: System-Stopping (must fix first)
1. **Fix 1.1** — get_config FFI returns proper Gleam Option (A-bot dead without this)
2. **Fix 2.1** — Add ::text casts to all uuid/timestamptz columns (most reads broken)
3. **Fix 3.1** — Align IssueStatus with DB (issue management broken)

### Phase 2: High Impact
4. **Fix 1.2** — gleamValueToJson missing types
5. **Fix 3.2** — Add FakeComplete to TaskStatus
6. **Fix 3.3** — Add AiBuilt to SkillSource
7. **Fix 3.4** — Remove Pending from MeetingStatus
8. **Fix 3.5** — Add Proposal to IssueType

### Phase 3: Medium Impact
9. Add heartbeat UPDATE to agent_sessions (is_s_still_idle always True)
10. Fix broadcast.stats() — remove status filter, fix priority comparison
11. Fix memory.save() — use id_decoder instead of full memory_decoder
12. Fix seed.gleam — split multi-statement SQL into separate queries
13. Fix psypi-doc-save — add missing params (content, saved_by, commit_hash, reason)
14. Fix psypi-my-id — add project and global fields to lit() expression
15. Fix a_db_reader.read_open_issues — change 'closed' to 'wont_fix','duplicate'
16. Fix a_orchestrator — write inter-review response to DB after call_monitor
17. Fix tool_commit — add git add before git commit
18. Fix compose() → compose_within_budget() in a_orchestrator

### Phase 4: Low Impact / Cleanup
19. Fix Error(_) -> Ok(default) anti-pattern across all modules
20. Add connection pooling to db.gleam
21. Add migration tracking table to simple_migrate
22. Fix memory.search_tool template — replace {count} with actual count
23. Fix psypi-issue-add — add created_by to params
24. Fix psypi-issues — add limit/offset params

---

## VERIFICATION NOTES

### Original Findings CONFIRMED: 116
The vast majority of trae-ai's 139 findings are accurate. The review was thorough and well-evidenced.

### Original Findings RETRACTED/CORRECTED: 5
- #111, #112: FAILED status IS valid in DB — original review was wrong
- #236: memory.search does NOT reference saved_at — original review was wrong
- #237: broadcast.stats status column — CONFIRMED correct
- #215: monitor_ai type vs issue_type column — CONFIRMED correct

### New Findings Added: 8
- Systemic ::text cast issue consolidated across 15+ modules
- 3 root cause categories identified
- Correction plan with prioritized fix order

---

## ESTIMATED EFFORT
- Phase 1: ~4 hours (3 fixes, highest impact)
- Phase 2: ~6 hours (5 fixes)
- Phase 3: ~10 hours (10 fixes)
- Phase 4: ~6 hours (6 fixes)
- **Total: ~26 hours** to fix all verified issues

**DO NOT IMPLEMENT until explicitly ordered by user.**
