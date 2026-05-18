# Generator Module Documentation

This folder contains Gleam code that generates JavaScript hook handlers for the Pi platform's event system. Each file defines behavior for specific Pi event hooks.

---

## File Overview

| File                           | Event Hook                 | Purpose                                 |
| ------------------------------ | -------------------------- | --------------------------------------- |
| `agent_lifecycle.gleam`        | `agent_start`, `agent_end` | Orchestrates A-agentbot lifecycle hooks |
| `agent_end_coordination.gleam` | `agent_end` (handler)      | Idle detection + wake-up coordination   |
| `before_agent_start.gleam`     | `before_agent_start`       | (DEPRECATED - no-op)                    |
| `session_start.gleam`          | `session_start`            | Session initialization, records model   |
| `model_select.gleam`           | `model_select`             | Records model changes                   |
| `tool_call.gleam`              | `tool_call`                | Auto-backup for edit operations         |
| `tool_result.gleam`            | `tool_result`              | Error detection + injection             |

---

## Detailed File Descriptions

### 1. `agent_lifecycle.gleam`

**Purpose:** Defines the A-agentbot (Autonomic Agentbot) lifecycle hooks for `agent_start` and `agent_end` events.

**Behavior:**
- `agent_start`: Currently a no-op. The S-agentbot is starting, so A-agentbot stays silent.
- `agent_end`: Delegates to `agent_end_coordination.handler_body()` for idle detection and wake-up coordination.

**Key Concept:** This coordinates the dual identity system where:
- **S-agentbot (Somatic)**: Does the actual coding work
- **A-agentbot (Autonomic)**: Monitors and coordinates in background

---

### 2. `agent_end_coordination.gleam`

**Purpose:** Handles the `agent_end` event to detect idle state and coordinate A-agentbot wake-up of S-agentbot.

**Behavior:**
1. When `agent_end` fires, logs a notification
2. Reads debounce duration from `system_config` table (key: `monitor_debounce_ms`)
3. Waits for the configured debounce period (default ~15s)
4. Checks `ctx.isIdle()` to see if S-agentbot is still idle
5. If still idle:
   - Reads `docs/MONITOR-BRIEF.md` (hard-to-find knowledge, <200 words)
   - Gets context usage info
   - Calls `callMonitor()` to compose a wake-up message
   - Sends message to S-agentbot via `pi.sendMessage()` with `triggerTurn: true`
6. If not idle, skips wake-up (S-agentbot is already working)

**Key Feature:** The debounce prevents premature wake-ups - if S-agentbot resumes within the debounce period, no wake-up message is sent.

---

### 3. `before_agent_start.gleam`

**Purpose:** (DEPRECATED - currently a no-op)

**History:** Previously used for database injection, but this approach was removed. The Monitor now uses direct messaging instead.

**Current Behavior:** Empty handler that does nothing.

---

### 4. `session_start.gleam`

**Purpose:** Initializes session state when a new Pi session starts.

**Behavior:**
- Records the current model being used via `record_current_model(ctx.model)`
- Non-blocking - failures are silently caught
- Silent operation (no UI notifications)

**Key Feature:** Ensures the system always knows which AI model is active for the session.

---

### 5. `model_select.gleam`

**Purpose:** Records model changes when the user/agent switches to a different AI model.

**Behavior:**
- When `model_select` event fires with a new model
- Calls `record_current_model(event.model)` to persist the change
- Non-blocking - failures are silently caught

**Key Feature:** Tracks model evolution throughout the session for monitoring/debugging.

---

### 6. `tool_call.gleam`

**Purpose:** Thin hook for `tool_call` events with automatic backup functionality.

**Behavior:**
- Currently implements **auto-backup** for `edit` operations only
- When `edit` tool is called:
  - Reads the file content before editing
  - Calls `save_version()` to create an automatic backup
  - Sets UI status to show backup success/failure
- Write operations (`write`) create new files, so backup is not needed

**Key Feature:** Provides safety net for edits - if something goes wrong, previous versions can be recovered.

---

### 7. `tool_result.gleam`

**Purpose:** Detects errors in tool execution results and injects them into the session.

**Behavior:**
1. Stringifies the tool result
2. Checks for error indicators:
   - `"error"` string
   - `"Error:"` string
   - `"execution error"`
   - `"tool_execution_blocked"`
   - `"is_error":true`
3. If error detected:
   - Extracts error message (tries multiple fields)
   - Logs error notification to UI
   - Injects error message into session via `pi.sendMessage()` with `customType: 'autonomic-error'`
   - Uses `triggerTurn: true` to force immediate S-agentbot attention

**Key Feature:** Ensures the S-agentbot is immediately aware of tool failures and can respond/fix them.

---

## Architecture Summary

These generators create JavaScript that runs in the Pi platform's hook system:

```
Pi Event → Hook Handler (generated JS) → Action
```

The A-agentbot (Autonomic) uses these hooks to:
- Monitor session state (session_start, model_select)
- Detect idle periods and wake up the S-agentbot (agent_end)
- Provide safety nets (tool_call auto-backup)
- Ensure error awareness (tool_result error injection)

This enables the dual-agentbot architecture where:
- S-agentbot does the work
- A-agentbot watches, coordinates, and intervenes when needed