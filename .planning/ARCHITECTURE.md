# psypi Architecture

## Overview

**psypi = Psyche + Pi** — A Pi extension written in Gleam that adds identity system and autonomous Monitor functionality.

```
psypi = Pi + Gleam extension + Identity + SOUL + Monitor
```

- **Pi**: Coding agent runtime (from `refers/pi/`)
- **psypi**: Extension adding identity system and Monitor

---

## Core Design: The Identity Chain

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. REQUIREMENT OF ID                                                        │
│     "Every action requires an agent_id. No exceptions."                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. IDENTITY COMPUTATION                                                      │
│     generate_semantic_id(autonomous, ...) → ID                              │
│     Pure function, no DB, no cache — computed fresh every time               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
           autonomous = false              autonomous = true
                    │                               │
                    ▼                               ▼
        ┌───────────────────────┐       ┌───────────────────────┐
        │  S-psypi-psypi-<sid>   │       │  A-psypi-psypi-<sid>  │
        │                       │       │                       │
        │  Session-driven       │       │  Autonomous-driven    │
        │  (Prompt-triggered)   │       │  (Event-triggered)    │
        └───────────────────────┘       └───────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. IDENTITIES (SOUL)                                                        │
│     Two identities, two SOULs in database                                    │
│     Same AI, different ID → different SOUL → different behavior                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. BEHAVIORS AND ACTIONS                                                    │
│     Worker: waits for prompts, executes tasks, uses tools                    │
│     Monitor: watches events, detects problems, creates notifications         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. TIME PHASES (Sequential Execution)                                       │
│     Phase 1: Worker acts on prompt                                           │
│     Phase 2: Monitor detects events                                          │
│     Phase 3: Worker receives Monitor's notifications                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  6. EVENTS / PROMPTS                                                         │
│     Prompt path: User → Worker (S-)                                        │
│     Event path: Hook → Monitor (A-) → notification → Worker (S-)            │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  7. NEXT RUN                                                                 │
│     ID computed fresh every time, cycle repeats                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Identity System

### ID Format

| Prefix | Trigger | Example |
|--------|---------|---------|
| `S-` | User prompts | `S-psypi-psypi-<session_id>` |
| `A-` | Events/Hooks | `A-psypi-psypi-<session_id>` |

### No Fallbacks Rule

Missing `session_id` is a **pure error** — no fallbacks.

```gleam
generate_semantic_id(autonomous, source, project, session_id, model)
  -> Result(String, IdentityError)
// Error(MissingSessionId) if session_id is ""
```

### SOUL in Database

From `souls` table:

| agent_id | name | traits |
|----------|------|--------|
| `S-psypi-psypi-<sid>` | Worker | speed=9, focus=task-completion |
| `A-psypi-psypi-<sid>` | Monitor | quality=10, focus=system-health |

### SOUL Modification Rules

| Type | Example | How to modify |
|------|---------|---------------|
| **Personal identity** | Name, meaning, traits | **Free to edit** |
| **Shared responsibilities** | "Monitor owns X" | **Requires meeting discussion** |

---

## Monitor System

### What is Monitor?

Monitor is NOT a separate agent. It's:
- `monitor.gleam` — Functions (notifications, model config)
- `monitor_ai.gleam` — AI functions (stats, alerts)
- Event hooks in `extension.js`
- Pi tools (`psypi-monitor-*`)

All run under **autonomous identity** (`A-psypi-psypi-<sid>`).

### Monitor Modes

```
┌─────────────────────────────────────────┐
│              MONITOR                     │
│  (single brain, 3 modes)                │
└─────────────────────────────────────────┘
                    ↑
    ┌───────────────┴───────────────┐
    │                               │
┌───┴────┐                    ┌─────┴────┐
│ SILENT │                    │   END    │
│(always)│                    │ (commit)  │
│        │                    │          │
│ health │                    │ review →  │
│ safety │                    │ pass/fail│
└────────┘                    └──────────┘
                    ↑
              ┌─────┴────┐
              │ MIDDLE   │
              │(proactive)│
              │          │
              │ consult  │
              └──────────┘
```

### Mode 1: Silent (Always Running)

Via event hooks:

| Event | Action |
|-------|--------|
| `tool_call` | Safety blocking, auto-backup |
| `session_start` | Initialize, health check |
| `before_agent_start` | Inject notifications |
| `tool_result` | Error detection |

### Mode 2: Middle of Workflow (Proactive)

Worker calls `psypi-monitor-consult` for advice.

### Mode 3: End of Workflow (Inter-review)

`psypi-commit` → Monitor reviews → PASS/FAIL → commit.

---

## System Prompt Injection

### The Gap

```
Monitor detects issue → writes to DB → Worker sleeps...
```

### The Solution

`before_agent_start` hook injects notifications into system prompt:

```javascript
pi.on('before_agent_start', async (event, ctx) => {
  const notifs = await get_pending_notifications(workerId);
  if (notifs.length > 0) {
    return {
      systemPrompt: event.systemPrompt + '\n\n' + formatAlerts(notifs)
    };
  }
});
```

### Notifications Table

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  agent_id TEXT NOT NULL,       -- Target worker
  priority TEXT DEFAULT 'medium',
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  read_at TIMESTAMP
);
```

---

## Entry Point

```
bin/psypi.mjs (Node.js entry, hand-written)
          │
          ▼
src/extension_generator.gleam (Gleam source)
          │
          ▼ gleam build
build/dev/javascript/psypi/ (compiled)
          │
          ▼ generate()
extension.js (Pi extension)
          │
          ▼ pi -e extension.js
Pi running with psypi tools
```

---

## Tool Blocked Protection

### What Blocks Tools

Returning `{ block: true }` from `tool_call` hook.

### Our Safety Patterns

Only block dangerous operations:

```javascript
const dangerousPatterns = [
  { pattern: /spawn.*pi/i, message: 'Infinite loop danger!' },
  { pattern: /rm.*-rf/i, message: 'Recursive delete!' },
  // ...
];
```

### Safe Hook Rules

1. Never return `{ block: true }` for normal cases
2. Never throw from hooks (wrap in try/catch)
3. Return consistent types per hook

---

## File Structure

```
psypi/
├── bin/psypi.mjs           # Entry point (hand-written)
├── src/
│   ├── agent_identity.gleam      # get_resolved_identity()
│   ├── agent_identity_logic.gleam # generate_semantic_id()
│   ├── agent_identity_types.gleam # Types
│   ├── monitor.gleam            # Notifications
│   ├── monitor_ai.gleam          # Stats, alerts
│   ├── extension_generator.gleam # Generates extension.js
│   └── pi_tool_call.gleam        # PiToolCall type
├── extension.js             # Generated (git-ignored)
├── docs/
│   └── MONITOR.md
└── .planning/
    ├── ARCHITECTURE.md     # This file
    └── SYSTEM-PROMPT-INJECTION.md
```

---

## Key Files

| File | Purpose |
|------|---------|
| `src/agent_identity_logic.gleam` | Pure ID generation |
| `src/extension_generator.gleam` | Generates extension.js |
| `src/monitor.gleam` | Notification functions |
| `extension.js` | Generated output |

---

## Development Workflow

```bash
# 1. Edit Gleam
vim src/monitor.gleam

# 2. Build
rm -rf build/ && gleam build

# 3. Regenerate extension.js
gleam run -m extension_generator

# 4. Test
psypi
```

---

## Next Phase

1. **Test** system prompt injection experiments
2. **Implement** Monitor → Worker notification round-trip
3. **Extend** Monitor to modify Gleam code (Phase 2)
4. **Evolve** system autonomously (Phase 3)