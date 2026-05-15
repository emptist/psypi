# Agent Identity — Single Source of Truth

## The Complete Flow Chain

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          REQUIREMENT OF ID                                   │
│                                                                              │
│  "Every action in psypi requires an agent_id. No exceptions."                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     generate_semantic_id(autonomous, ...)                    │
│                                                                              │
│  Pure function, no DB lookup, no cache — computed fresh every time          │
│                                                                              │
│  Parameters:                                                                 │
│    autonomous: Bool  ← THE DECISION POINT                                  │
│    source: String                                                         │
│    project: String                                                         │
│    session_id: String                                                      │
│    model: String                                                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
           autonomous = false              autonomous = true
                    │                               │
                    ▼                               ▼
        ┌───────────────────────┐       ┌───────────────────────┐
        │  S-psypi-psypi-unknown │       │   A-psypi-psypi        │
        │                       │       │                       │
        │  Session-driven        │       │  Autonomous-driven   │
        │  (Prompt-triggered)    │       │  (Event-triggered)    │
        └───────────────────────┘       └───────────────────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IDENTITIES (SOUL)                                   │
│                                                                              │
│  From souls table:                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ agent_id: S-psypi-psypi-unknown                                       │   │
│  │ name: Worker                                                          │   │
│  │ traits: { speed: 9, quality: 7, autonomy: 5, focus: "task-completion" }│   │
│  │ content: "I am the prompt-driven task executor..."                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ agent_id: A-psypi-psypi                                               │   │
│  │ name: Monitor                                                        │   │
│  │ traits: { speed: 6, quality: 10, autonomy: 9, focus: "system-health" }│   │
│  │ content: "I am the event-driven system guardian..."                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Same AI, different identity → different behaviors and actions              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
        ┌───────────────────────┐       ┌───────────────────────┐
        │    BEHAVIORS &        │       │    BEHAVIORS &        │
        │    ACTIONS (Worker)   │       │    ACTIONS (Monitor)  │
        │                       │       │                       │
        │  • Waits for prompts  │       │  • Watches for events │
        │  • Executes tasks     │       │  • Detects problems  │
        │  • Uses tools         │       │  • Analyzes system   │
        │  • Reports results    │       │  • Creates alerts    │
        │  • Rest after work   │       │  • Rests while idle  │
        └───────────────────────┘       └───────────────────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TIME PHASES                                        │
│                                                                              │
│  The system runs in continuous sequential phases:                            │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │    ┌─────────┐     ┌─────────┐     ┌─────────────┐                │   │
│  │    │ Phase 1 │ ──► │ Phase 2 │ ──► │ Phase 3     │                │   │
│  │    │ Worker  │     │ Monitor │     │ Worker      │                │   │
│  │    │ Works   │     │ Detects │     │ Receives    │                │   │
│  │    └─────────┘     └─────────┘     └─────────────┘                │   │
│  │         │               │                  │                      │   │
│  │         └───────────────┴──────────────────┘                      │   │
│  │                     Loop continues                                  │   │
│  │                                                                     │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Phase 1: Worker acts on user prompt                                        │
│  Phase 2: Monitor detects events while Worker rests                         │
│  Phase 3: Worker receives Monitor's notifications before next task          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EVENTS / PROMPTS                                    │
│                                                                              │
│  Two wake-up paths for the same AI:                                         │
│                                                                              │
│  ┌─────────────────────────────────┐   ┌─────────────────────────────────┐  │
│  │           PROMPTS               │   │           EVENTS                 │  │
│  │                                 │   │                                 │  │
│  │  Type: User input               │   │  Type: Pi hooks firing           │  │
│  │  Trigger: Human types           │   │  Trigger: System conditions     │  │
│  │  ID: S- (autonomous=false)      │   │  ID: A- (autonomous=true)      │  │
│  │  Flow: Prompt → Worker → Act    │   │  Flow: Event → Monitor → Detect │  │
│  │                                 │   │                                 │  │
│  │  Example:                       │   │  Example:                       │  │
│  │  "Fix the bug in file.ts"       │   │  tool_result with isError=true  │  │
│  │                                 │   │                                 │  │
│  └─────────────────────────────────┘   └─────────────────────────────────┘  │
│                                                                              │
│  Prompt path: User → Worker (S-)                                           │
│  Event path: Hook → Monitor (A-) → notification → Worker (S-)              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            NEXT RUN                                          │
│                                                                              │
│  The cycle repeats with fresh IDs computed every time:                      │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                                                                     │   │
│  │    User Prompt or Event                                             │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    generate_semantic_id(autonomous, ...)  ← Fresh computation!     │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    S- or A- ID (depending on autonomous)                           │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    Lookup SOUL from DB (by agent_id)                               │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    Behaviors & Actions based on SOUL                                │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    Write to DB (activity_log, notifications, etc.)                 │   │
│  │            │                                                        │   │
│  │            ▼                                                        │   │
│  │    Next prompt or event triggers the cycle again                   │   │
│  │                                                                     │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  Key property: ID is ALWAYS computed fresh, NEVER cached or stored          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## The Identity Continuum

Same AI, different trigger → different ID → different SOUL → different behavior

| Parameter | Worker (S-) | Monitor (A-) |
|-----------|-------------|--------------|
| `autonomous` | `false` | `true` |
| Trigger | User prompts | Events/Hooks |
| Prefix | `S-` (Session) | `A-` (Autonomous) |
| ID Example | `S-psypi-psypi-unknown` | `A-psypi-psypi` |
| SOUL Traits | speed=9, focus=task-completion | quality=10, focus=system-health |
| Behavior | "User asked me to do X" | "Tool error detected → analyze → notify" |

---

## Agent ID Required for All Actions

Every action in psypi requires an `agent_id`. No exceptions.

```gleam
// Gleam: generate_semantic_id() - PURE function, no DB lookup
generate_semantic_id(autonomous: Bool, source, project, session_id, model)
  → "S-psypi-psypi-unknown"  // autonomous=false
  → "A-psypi-psypi"          // autonomous=true
```

### Convention: How to Get ID

| Context | How to Get ID |
|---------|---------------|
| Tool calls (Worker) | `get_resolved_identity(false, sessionId, ...)` → S- |
| Hooks/Events (Monitor) | `get_resolved_identity(true, ...)` → A- |
| No parameters needed | `psypi-my-id` tool → S- |
| Monitor/Partner ID | `psypi-autonomic-id` tool → A- |

---

## Two Identities, Two SOULs

From `souls` table in psypi database:

```sql
souls table:
  agent_id   → "S-psypi-psypi-unknown" (Worker)
             → "A-psypi-psypi" (Monitor)
  name       → "Worker" / "Monitor"
  content    → Markdown describing WHO this identity is
  traits     → { speed: 9, quality: 7, autonomy: 5 }
```

### SOUL Modification Rules

| Type | Example | How to modify |
|------|---------|---------------|
| **Personal identity** | Name ("Worker"), meaning, traits | **Free to edit anytime** |
| **Shared responsibilities** | "Monitor owns skill_indexing" | **Requires discussion in meetings** |

---

## Time Phases: Sequential Execution

```
┌─────────────────────────────────────────────────────────────┐
│                    Continuous Loop                            │
│                                                             │
│  ┌─────────┐     ┌─────────┐     ┌─────────────┐          │
│  │ Phase 1 │ ──► │ Phase 2 │ ──► │ Phase 3     │          │
│  │ Worker  │     │ Monitor │     │ Worker      │          │
│  │ acts    │     │ detects │     │ receives    │          │
│  └─────────┘     └─────────┘     └─────────────┘          │
│       │               │                  │                 │
│       │               │                  │                 │
│       └───────────────┴──────────────────┘                 │
│                     Loop continues                           │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Worker Acts
- User prompt arrives
- `before_agent_start` hook reads notifications from DB
- Worker receives system prompt with pending alerts
- Worker executes task

### Phase 2: Monitor Detects
- Events fire (tool_result, session_start, etc.)
- Hook with `autonomous=true` runs
- Monitor analyzes system state
- Monitor writes to `notifications` table

### Phase 3: Worker Receives
- Next user prompt triggers `before_agent_start`
- Hook reads pending notifications for Worker
- Notifications injected into system prompt
- Worker acknowledges and acts

---

## Events vs Prompts: Two Wake-up Paths

| Path | Trigger | ID Used | Example |
|------|---------|---------|--------|
| **Prompts** | User input | `S-` | "Do X task" |
| **Events** | Hook execution | `A-` | tool_error detected |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Two Trigger Points                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Prompt Trigger              Event Trigger                    │
│  get_resolved_identity()   get_resolved_identity()          │
│  (autonomous=false)        (autonomous=true)                 │
│         │                           │                        │
│         └────────────┬──────────────┘                        │
│                      ↓                                        │
│              activity_log table                               │
│         (agent_id, activity, context)                         │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Pi ctx.sessionManager.getSessionId()
        │
        ▼
get_resolved_identity(autonomous, session_id, project, ...)
        │
        ▼
AgentIdentity { id: "S-" or "A-", session_id, project, source, ... }
        │
        ├──► activity_log (ID Trigger: "get_resolved_identity")
        │
        └──► Returns to JS, subsequent operations use this ID
             │
             ├──► activity_log (Event Trigger: "tool_call")
             └──► notifications table (Monitor → Worker)
```

---

## Implementation Details

### 1. Gleam Module: agent_identity.gleam

```gleam
pub fn get_resolved_identity(
  autonomous: Bool,     // false → S-, true → A-
  session_id: String,
  project: String,
  _git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> Result(AgentIdentity, IdentityError)
```

### 2. Gleam Module: agent_identity_logic.gleam

```gleam
pub fn generate_semantic_id(autonomous, source, project, session_id, model) -> String {
  let prefix = case autonomous {
    True -> "A"   // Autonomous (event-driven)
    False -> "S"  // Session (prompt-driven)
  }
  // ... generates full ID
}
```

### 3. Generated Code: extension.js

```javascript
// Worker ID (autonomous defaults to false)
agent_identity_get_resolved_identity(false, _sessionId, 'psypi', '', '', 'psypi', '')

// Monitor ID (autonomous = true)
agent_identity_get_resolved_identity(true, '', 'psypi', '', '', 'psypi', '')
```

---

## Database Records

```sql
-- Prompt Trigger (Worker/S-)
agent_id: S-psypi-psypi-unknown
activity: get_resolved_identity
context: {"autonomous": false, "source": "psypi", "project": "psypi", "session_id": "..."}

-- Event Trigger (Monitor/A-)
agent_id: A-psypi-psypi
activity: tool_result
context: {"tool": "read", "isError": true, "error": "File not found"}
```

---

## Key Insight

> **ID is computed fresh from function call parameters — never from database, never cached.**

This is why Gleam was chosen:
- TypeScript: `id = query_from_db()` → caches → stale
- Gleam: `generate_semantic_id()` → pure function → always fresh

---

## Status

- [x] `autonomous` parameter (replaces `permanent`)
- [x] `A-` prefix for Autonomous (replaces `P-`)
- [x] `S-` prefix for Session (unchanged)
- [x] Two SOUL entries in database
- [x] Sequential execution: Worker → Monitor → Worker
- [ ] System prompt injection (experiments pending)