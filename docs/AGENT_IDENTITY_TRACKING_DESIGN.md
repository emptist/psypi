# Agent Identity Tracking Design

## Implemented Features

### ✅ Tracking Status

| Tracking Layer | Table | Trigger | Status |
|---------------|-------|---------|--------|
| Activity | `activity_log` | Every tool call | ✅ Implemented |
| Auto-tracking | `activity_log` | Via extension.js generator | ✅ Implemented |
| Session | `agent_sessions` | Session start | ⏳ Future |

### How It Works

**1. ID Trigger Point** (Always active):
- Every call to `get_resolved_identity()` automatically logs to `activity_log`
- Records: `agent_id`, `activity="get_resolved_identity"`, context with parameters

**2. Auto Tool Tracking** (Implemented):
- Modified `extension_generator.gleam` to auto-inject tracking
- Every Pi tool call automatically logs to `activity_log`
- Records: `agent_id`, `activity="tool_call"`, context with tool name, params, success

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Two Trigger Points                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ID Trigger                   Event Trigger                 │
│  get_resolved_identity()     Pi Tool / Event (future)      │
│         │                            │                      │
│         └────────────┬───────────────┘                      │
│                      ↓                                      │
│            emit_activity()                                  │
│                      ↓                                      │
│            activity_log table                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. Gleam Module: agent_identity.gleam
- Modified `get_resolved_identity` to call `activity_log.log_activity`
- Logs: `agent_id`, `activity="get_resolved_identity"`, context with all parameters

### 2. Generator: extension_generator.gleam
- Added `trackActivity()` helper function
- Added `log_activity` import
- Every tool auto-calls `trackActivity(toolName, params, result)`

### 3. Generated Code: extension.js
- Imports: `get_resolved_identity`, `log_activity`
- Each tool executes: Gleam call → unwrap result → trackActivity()

## Database Records

```sql
-- ID Trigger
agent_id: S-psypi-psypi
activity: get_resolved_identity
context: {"model": "", "source": "psypi", "project": "psypi", "permanent": false, "session_id": ""}

-- Tool Trigger  
agent_id: S-psypi-psypi
activity: tool_call
context: {"tool": "psypi-tasks", "params": {"status": "pending"}, "success": true}
```

## Future Enhancements

- Session tracking via `agent_sessions` table
- Detailed activity tracking via Pi Tool: `psypi-log-activity(action, context)`
- Event-based tracking system

## Files Modified

| File | Change |
|------|--------|
| `agent_identity.gleam` | Added activity_log call |
| `extension_generator.gleam` | Added auto-tracking code |
| `extension.js` | Regenerated with tracking |

The key insight is that **regardless of how it's triggered, the underlying logic is the same**:

```gleam
// Unified emission function
emit_activity(
  actor: AgentIdentity,      // WHO (always required)
  action: String,            // WHAT (what happened)
  target: Option(Target),    // WHICH (optional)
  context: JSON             // DETAILS (optional)
)
```

This follows Functional Programming principles:
- Core function does one thing (return identity)
- Side effects are handled by separate functions (emit_activity)
- Implementation can change anytime without affecting callers

## Two Trigger Points

| Trigger Point | When | Parameters Available |
|--------------|------|---------------------|
| **ID Trigger** | `get_resolved_identity()` called | actor (always), action="get_id", target=None, context={...} |
| **Event Trigger** | Via Pi Tool / Event | actor (always), action, target, context (full) |

Both trigger points feed into the same `emit_activity` function - they don't conflict.

### ID Trigger (Current Implementation)
- Every call to `get_resolved_identity` triggers activity logging
- Records: "someone got their identity"
- Missing: detailed event parameters (that's fine - foundation only)

### Event Trigger (Future Extension)
- Via Pi Tool: `psypi-log-activity(action, target, context)`
- Via Event: Emit events when AI performs actions
- Records: full details of what AI is doing

## Implementation Status

### ✅ Step 1: DONE - Add emit_activity to activity_log module
- Activity_log module already had `log_activity` function

### ✅ Step 2: DONE - Modify get_resolved_identity to trigger activity logging
- Modified `agent_identity.gleam` to call `activity_log.log_activity` after getting identity
- Logs: agent_id, activity="get_resolved_identity", context with all parameters

### ✅ Step 3: DONE - Test the implementation
- Build: SUCCESS
- Test: SUCCESS
- Verified activity_log has new record

### ⏳ Step 4: (Future) Add event trigger via Pi Tool
- Add psypi-log-activity tool
- Connect to emit_activity

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `activity_log.gleam` | Modify | Add emit_activity function |
| `agent_identity.gleam` | Modify | Call emit_activity after getting identity |

### Code Changes

#### activity_log.gleam - Add emit_activity

```gleam
pub fn emit_activity(
  actor: AgentIdentity,
  action: String,
  target: Option(String),
  context: String,
) -> promise.Promise(Result(Nil, ActivityLoggingError)) {
  // Insert into activity_log
  // ...
}
```

#### agent_identity.gleam - Trigger on get_resolved_identity

```gleam
pub fn get_resolved_identity(...) {
  // Existing logic to get identity
  let identity = ...
  
  // NEW: Emit activity (fire and forget - don't block)
  emit_activity(identity, "get_resolved_identity", None, "{...}")
  
  identity
}
```

## Future Extension

### Future: Detailed Activity Tracking via Pi Tools or Events

The current design is a **simple foundation**. In the future, detailed AI activity tracking could be implemented via:

- **Pi Tools**: Create tools like `psypi-log-activity(activity_type, context)` that AI can call
- **Events**: Emit events when AI performs actions, with event listeners logging to activity_log

This allows:
- More granular tracking (what exactly the AI is doing)
- Better context (tool parameters, results, etc.)
- Extensible (add new activity types without code changes)

### Current Implementation (Simple Foundation)

For now, implement the basic tracking:
- Every call to `get_resolved_identity` logs one activity record
- This establishes the tracking mechanism
- Future extensions can build on this infrastructure
