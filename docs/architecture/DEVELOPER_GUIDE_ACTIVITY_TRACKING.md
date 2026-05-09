# Developer Guide: Activity Tracking

## Overview

psypi has a built-in activity tracking system that automatically logs AI agent actions to the database.

## Two Trigger Points

### 1. ID Trigger (Automatic)

Every call to `get_resolved_identity()` automatically triggers activity logging:

```gleam
// In agent_identity.gleam
pub fn get_resolved_identity(...) {
  let identity = ...
  
  // Automatically logs to activity_log
  activity_log.log_activity(identity.id, "get_resolved_identity", context)
  
  identity
}
```

**When triggered:**
- Agent calls `psypi-my-id` or `psypi-partner-id`
- Any internal code calls `get_resolved_identity()`

### 2. Tool Trigger (Automatic via Generator)

Every Pi tool call automatically triggers activity logging:

```javascript
// In extension.js (auto-generated)
async function execute(...) {
  const result = await gleam_tool(...);
  const r = unwrapGleamResult(result);
  
  // Auto-tracking - logs every tool call!
  trackActivity("tool-name", params, r);
  
  return ...;
}
```

**When triggered:**
- Any Pi tool is executed (task-add, issue-add, skill-build, etc.)

## Database Schema

```sql
CREATE TABLE activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id VARCHAR(100) NOT NULL,
  activity VARCHAR(100) NOT NULL,
  context JSONB DEFAULT '{}',
  git_hash VARCHAR(20),
  git_branch VARCHAR(100),
  environment VARCHAR(50) DEFAULT 'development',
  timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

## Viewing Activity

```sql
-- View recent activity
SELECT agent_id, activity, context, timestamp 
FROM activity_log 
ORDER BY timestamp DESC LIMIT 20;

-- View specific agent activity
SELECT * FROM activity_log 
WHERE agent_id = 'S-psypi-psypi'
ORDER BY timestamp DESC;

-- View tool calls only
SELECT * FROM activity_log 
WHERE activity = 'tool_call'
ORDER BY timestamp DESC;
```

## Adding Custom Activity Tracking

### Option 1: Call log_activity directly

```gleam
import psypi_cli/activity_log

// In any Gleam function
pub fn do_something() {
  // Your logic...
  
  // Log activity
  activity_log.log_activity(
    agent_id,           // AgentIdentity.id
    "custom_action",   // Activity name
    "{}"               // JSON context
  )
}
```

### Option 2: Via Pi Tool (Future)

A future Pi tool `psypi-log-activity` will allow AI to log custom activities.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Activity Tracking                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ID Trigger                   Tool Trigger                   │
│  get_resolved_identity()     Pi Tool execute()              │
│         │                            │                       │
│         └────────────┬───────────────┘                       │
│                      ↓                                       │
│            activity_log.log_activity()                        │
│                      ↓                                       │
│                 activity_log table                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `activity_log.gleam` | Activity logging module |
| `agent_identity.gleam` | Identity + ID trigger |
| `extension_generator.gleam` | Tool trigger injection |
| `extension.js` | Generated with tracking |
