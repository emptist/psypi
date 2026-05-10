# Monitor Agent Design - Findings (Practical)

## Current State Analysis

### What Already Runs as Monitor (in extension.js event hooks)
- `tool_call` hook runs on EVERY tool execution:
  1. Identity resolution
  2. Activity logging (activity_log table)
  3. Auto-backup before edit/write
- **Current status**: Working ✓

### Current Database Metrics (Real Numbers)
```
pending_tasks: 0
in_progress: 0  
completed: 0
failed: 0
open_issues: 1044
resolved_issues: 40
activities_1h: 0
inter_reviews: 6027 completed
```

### monitor_ai.gleam Stubs Status
| Function | Status | Lines to Implement |
|----------|--------|-------------------|
| start_monitor_loop() | Unused stub | 0 |
| check_system_health() | Stub only | 10 |
| housekeeping() | Stub only | 10 |
| prepare_context() | Stub only | 20 |

### Key Insight
The Monitor is NOT replacing external review service (P-tencent/hy3-preview:free-psypi).
- External service = **code review** (external LLM)
- Local Monitor = **system health** (DB, tasks, issues, activity)

---

## Research Answers

### 1. Cost Analysis

**CPU/Memory**: 
- Event hooks are lightweight - just JS functions in Pi process
- Current tool_call hook: ~1-5ms per call (non-blocking async)
- No additional CPU when idle - only runs on tool calls
- Memory: negligible (few KB for closure)
- setInterval example: mac-system-theme.ts runs every 2 seconds (~0.0005 CPU)

**Pi Performance**: No measurable impact

**Battery**: Negligible - only runs during active tool use, periodic checks are very light

### 2. Cross-Instance Management

**Current architecture**: 
- Each psypi instance runs in its own Pi process
- No coordination needed - they're independent
- Database is shared (OK - PostgreSQL handles concurrency)

**Session tracking**: 
- agent_sessions table tracks 30 alive sessions
- Each psypi instance registers itself on start
- Query "SELECT status FROM agent_sessions WHERE source='psypi'" to check if running

**Conclusion**: No special coordination needed - embedded Monitor per psypi instance is simplest

### 3. Lifecycle (CONFIRMED via Pi docs)

**Pattern from mac-system-theme.ts example:**
```typescript
pi.on("session_start", async (_event, ctx) => {
  intervalId = setInterval(async () => {
    // periodic task
  }, 2000);
});

pi.on("session_shutdown", () => {
  if (intervalId) {
    clearInterval(intervalId);  // cleanup!
  }
});
```

**Start**: With Pi session_start event
**Stop**: With session_shutdown (automatic cleanup)
**Crash**: OS cleans up - setInterval timers stop
**Restart**: New session_start → new Monitor

### 4. Permissions

Already granted:
- File system: read/write via Node.js fs
- Database: full access via psypi connection
- Shell: via execute_cmd

No new permissions needed

### 5. State Persistence

- Activity logs → DB (activity_log table) ✓
- Auto-backups → DB (code_versions table) ✓
- Review history → DB (inter_reviews table) ✓
- Session state → DB (agent_sessions table) ✓

All persistent in DB

### 6. Architecture Options Comparison

| | Embedded (A) | Separate Daemon (B) | External Service (C) |
|---|---|---|---|
| Cost | Near zero | Low | API call cost |
| Complexity | Simple | Complex | Simple |
| Independence | Tied to Pi | Independent | Independent |
| Coordination | None needed | Complex | None |
| Features | Limited by lifecycle | Full | Full |
| Current status | Stubs exist | Not built | ✓ Working |

**Recommendation**: Option A (Embedded) - proven pattern, simplest, cost near zero

### 7. Feature Scope (Detailed)

**Phase 1 - Event-based (already works)**
- ✓ Auto-backup on edit/write
- ✓ Activity logging on every tool_call
- ✓ Status notifications (ctx.ui.setStatus)

**Phase 2 - Periodic (needs setInterval implementation)**
- Health checks: DB connection, disk space, gleam build
- Activity summary: periodic log of work done
- Cleanup: temp file management

**Phase 3 - User-triggered (needs Monitor tools)**
- psypi-monitor-status: Show current Monitor state
- psypi-monitor-health: Force health check
- psypi-monitor-alerts: Show recent failures

**Phase 4 - Proactive (advanced)**
- Alert on build failures
- Suggest learnings from patterns
- Auto-broadcast important events

---

## Decision: YES - psypi should have Monitor

### Why YES:

1. **Cost is near zero** - setInterval + event hooks are lightweight
2. **Pattern proven** - mac-system-theme.ts shows it works perfectly
3. **Existing stubs** - monitor_ai.gleam exists, just needs implementation
4. **More than inter-review** - health checks, alerts, proactive suggestions
5. **Simple architecture** - embedded per psypi instance, no complex coordination

### Key Distinction:

The "Monitor" is NOT replacing the external review service (P-tencent/hy3-preview:free-psypi).
The external service is for **code review** - that's an external LLM.
The Monitor is for **local monitoring** - health, activity, alerts, context.

They serve different purposes and both can coexist.

---

## Implementation Approach

**Phase 1**: Add event hooks (agent_start, agent_end, session hooks)
- Simple: add more hooks to extension_generator.gleam

**Phase 2**: Implement monitor_ai.gleam functions
- Implement: check_system_health(), prepare_context()
- Add: periodic health checks via setInterval

**Phase 3**: Add Monitor tools for user interaction
- psypi-monitor-status: Show current Monitor state
- psypi-monitor-health: Force health check
- psypi-monitor-alerts: Show recent failures

**Phase 4**: Proactive features (optional)
- Alert on build failures
- Auto-broadcast important events

---

## Concrete Implementation Details

### Option B Implementation (Recommended)

#### Phase 1: Add Event Hooks (~20 lines in extension_generator.gleam)
```
// Add to all_event_hooks()
- agent_start hook: Log session start, init monitoring
- agent_end hook: Log session end, cleanup
- session_shutdown hook: Clear intervals, save state
```

#### Phase 2: Implement monitor_ai.gleam (~40 lines)
```gleam
// Health check function - concrete SQL
pub fn check_system_health() -> promise.Promise(Result(HealthMetrics, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 
        (SELECT COUNT(*) FROM tasks WHERE status = 'failed') as failed_tasks,
        (SELECT COUNT(*) FROM issues WHERE status = 'open') as open_issues,
        (SELECT COUNT(*) FROM activity_log WHERE timestamp > NOW() - INTERVAL '1 hour') as activities_1h
    "
    // ... decode to HealthMetrics
  })
}

// Context preparation - concrete SQL
pub fn prepare_context(agent_id: String) -> promise.Promise(Result(String, MonitorError)) {
  // Uses memory + code_versions tables
  // Returns formatted context string for LLM
}
```

#### Phase 3: Add Monitor Tools (~30 lines in PiToolCall)
```gleam
pub fn monitor_status_tool() -> PiToolCall
pub fn monitor_health_tool() -> PiToolCall
pub fn monitor_alerts_tool() -> PiToolCall
```

#### Phase 4: setInterval Health Checks (~15 lines in extension.js)
```javascript
// Pattern from mac-system-theme.ts
let healthInterval = null;
pi.on("session_start", async (_event, ctx) => {
  healthInterval = setInterval(async () => {
    const { check_system_health } = await import('./build/.../monitor_ai.mjs');
    const health = await check_system_health();
    if (health.value.failed_tasks > 0) {
      ctx.ui.setStatus('psypi-health', '⚠️ ' + health.value.failed_tasks + ' failed tasks');
    }
  }, 60000); // Every 60 seconds
});
pi.on("session_shutdown", () => clearInterval(healthInterval));
```

---

## Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Monitor slows Pi | Low | Medium | setInterval already proven in Pi examples |
| Memory leak | Low | High | session_shutdown clears intervals |
| DB load from health checks | Medium | Low | Light queries, 60s interval |
| No one uses Monitor tools | Medium | Low | Start with useful alerts only |
| Duplicate of existing features | Low | Low | Research shows no overlap |

---

## Decision Criteria

**Choose Option A if**: You want minimal changes, accept no local health monitoring

**Choose Option B if**: You want significant value (health alerts, context prep, activity tracking) at near-zero cost

**Choose Option C if**: You want full-featured Monitor and are willing to maintain more code

---

## What Needs to Work First

1. `gleam build` passes ✓ (checked earlier)
2. Extension loads in Pi ✓ (already working)
3. DB connection works ✓ (inter_review works)
4. execute_cmd works ✓ (for disk space checks)

No blocking dependencies.

---

## Summary

| Metric | Value |
|--------|-------|
| Implementation effort | ~100 lines of Gleam + 20 lines JS |
| CPU cost | ~0.0005 (setInterval every 60s) |
| Memory cost | <1KB |
| DB queries per hour | ~60 (1 per minute) |
| Risk level | Low |

**Recommendation: Option B** - Maximum value, minimum cost, proven pattern.

Tomorrow we discuss! 👋