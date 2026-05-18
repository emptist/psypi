# Architecture Analysis: psypi Monitor Design

## Context: What We Discussed

### Original Premise (Paradox Found)
> "Build a Monitor AI with the same power as the Agentbot AI"

**Problem discovered:** "Monitor" was being built as a SEPARATE AI with `complete()` (text-only) → `psypi-autonomic-exec` bridge. This is WEAKER than Agentbot, not equal.

### Corrected Understanding
- **Agentbot (no prefix)**: Triggered by user/system prompts
- **Monitor (P- prefix)**: Triggered by EVENTS (hooks), has FULL tool access, finds work nobody asked for

Monitor is the SAME Pi agent, just with a different trigger mechanism + identity.

---

## Reference Projects Analysis

### 1. Pi (coding-agent) - Core Reference

**Architecture:**
- `AgentSession` manages agent lifecycle, event subscription, tool registry
- `Agent` wraps the low-level agent loop, owns state (tools, messages), emits events
- `ExtensionRunner` handles extension loading and event emission
- **Hooks are FIRST-CLASS**: `beforeToolCall`, `afterToolCall` are on the Agent itself

**Key insight from Pi's Extension system:**
```
Agent
  ├── beforeToolCall?: (context, signal) => Promise<BeforeToolCallResult | undefined>
  └── afterToolCall?: (context, signal) => Promise<AfterToolCallResult | undefined>
```

These are NOT extension hooks - they're on the core Agent. Extensions wrap them via `ExtensionRunner`.

**Extension Events (from types.ts):**
```
SessionEvents: session_start, session_before_switch, session_before_fork, session_before_compact,
               session_compact, session_shutdown, session_before_tree, session_tree

AgentEvents: context, before_provider_request, after_provider_response, before_agent_start,
             agent_start, agent_end, turn_start, turn_end,
             message_start, message_update, message_end,
             tool_execution_start, tool_execution_update, tool_execution_end,
             model_select, thinking_level_select, user_bash, input

ToolEvents: tool_call (can BLOCK), tool_result (can MODIFY)
```

**Tool execution model:**
- `ToolDefinition` has `execute()` that receives `ctx: ExtensionContext`
- `ExtensionContext` provides: `ui`, `sessionManager`, `modelRegistry`, `model`, `isIdle()`, `signal`, `abort()`
- Tools can be blocking (`block: true, reason: string`) or result-modifying

**Key Pi SDK patterns:**
```typescript
// Create agent session
const { session } = await createAgentSession({
  authStorage, modelRegistry, tools: codingTools(process.cwd()),
  sessionManager: SessionManager.inMemory(),
});

// Subscribe to events
session.subscribe((event) => { /* handle */ });

// Send messages
await session.prompt(text);
await session.steer(text);    // Interrupt current turn
await session.followUp(text); // Queue for after current turn

// Control tools
session.setActiveToolsByName(['read', 'bash', 'edit', 'write']);

// Send custom messages
await session.sendCustomMessage({ customType: 'monitor', content: [...] }, { triggerTurn: true });
```

**Pi's model for "two modes" (from AgentSession):**
- `steer()` - interrupt current turn with message (steering queue)
- `followUp()` - queue message for after current turn (follow-up queue)
- `sendCustomMessage()` with `deliverAs: "steer" | "followUp" | "nextTurn"`
- These are built-in! The agent already supports multi-mode messaging

### 2. Puter.js - Architecture Patterns

**Observations:**
- Agentbot-based architecture with sandbox isolation
- Extension system for adding capabilities
- Focus on UI (gui/), services (agentbot/), and dev-center

**Relevance:** The extension pattern in puter could inspire how psypi extends Pi.

### 3. Lively4-core - Event-Driven Pattern

**Observations:**
- Self-modifying browser environment
- Web Agentbot system for background processing
- Component-based architecture with event propagation

**Key insight from Lively4:**
> "When a parent component contains child components, state changes must be explicitly propagated"
> "Child components don't automatically inherit instance variables from their container"

This suggests the Monitor needs to PROACTIVELY communicate state changes, not just passively observe.

---

## Current psypi Code Analysis

### What Exists

| Component            | Location                                    | Status                               |
| -------------------- | ------------------------------------------- | ------------------------------------ |
| Extension generator  | `src/extension_generator.gleam` (476 lines) | Works - generates extension.js       |
| Pi tools             | 27 tools in extension.js (752 lines)        | Working                              |
| Session hooks        | 6 hooks registered                          | Partially working                    |
| Monitor LLM          | `callMonitor()` in extension.js             | Broken - uses `complete()` text-only |
| `createAgentSession` | `session_start_hook`                        | Exists but incomplete                |

### Hooks Inventory

| Hook                 | Purpose                                 | Status                           |
| -------------------- | --------------------------------------- | -------------------------------- |
| `tool_call`          | Safety check, activity log, auto-backup | ✅ Working                        |
| `session_start`      | Spawn Monitor via `createAgentSession`  | ⚠️ Incomplete - wrong import path |
| `before_agent_start` | Enable all tools + analyze              | ❌ DEAD - wrong import path       |
| `agent_start`        | Track agent activity                    | ✅ Empty (silent)                 |
| `agent_end`          | No auto-spawning per turn               | ✅ Correct                        |
| `tool_result`        | Auto-file issues for errors             | ✅ Working                        |

### Dead Code Found

1. **`before_agent_start_hook`** (extension_generator.gleam:177-193)
   - Imports from `./build/dev/javascript/psypi/monitor_ai.mjs` → path doesn't exist in production
   - `analyze_and_act()` never runs

2. **`analyze_and_act()`** (monitor_ai.gleam:489-539)
   - Called by dead hook, doesn't actually act
   - Returns DB row as JSON, but nothing uses it

3. **`session_start_hook`** (extension_generator.gleam:128-175)
   - Line 153: `import('./build/dev/javascript/psypi/monitor_ai.mjs')` - same wrong path
   - Gleam import will fail in production

4. **`callMonitor`** (extension.js:52-73)
   - Uses `complete()` → text only, no tool calls
   - Monitor LLM can't act directly, needs bridge
   - This is the core architectural problem

---

## Core Problem: Two Architectures Collided

### Architecture A: What We Built
```
Event → Hook → callMonitor (LLM text) → psypi-autonomic-exec → Gleam → DB
```

### Architecture B: What We Should Build
```
Event → Hook → P-Monitor (real Pi agent with tools) → DB
```

Architecture A adds unnecessary complexity:
- LLM adds latency and cost for things that are just DB queries
- The `psypi-autonomic-exec` bridge is a workaround for the LLM not having tools
- Monitor is WEAKER than Agentbot because it can't use tools directly

---

## Key Questions for Redesign

### Q1: How does P-Monitor get triggered by events?

Currently: `session_start_hook` tries to spawn a new `createAgentSession` Monitor.

**Questions:**
- Is the Monitor a SEPARATE Pi session, or a mode within the SAME session?
- If separate: how does it communicate with Agentbot?
- If same: how does it run "in background" without blocking Agentbot?
- What events should trigger Monitor actions?

### Q2: What is the communication pattern between Agentbot and P-Monitor?

**Options:**
1. **Shared state**: Both read/write DB, no direct communication
2. **Event bus**: Agentbot emits events, Monitor subscribes
3. **Tool calls**: Agentbot calls Monitor tools, Monitor calls Agentbot tools
4. **One agent**: Same agent handles both, mode is just context

### Q3: How does P-Monitor find its own work?

Current: Generic prompt "Investigate and take action" on session_start.

**Problems:**
- Too vague - LLM won't know what to look for
- No trigger conditions (e.g., "if failed_tasks > 0, create follow-up task")
- No work queue or priority system

### Q4: What's the difference between Agentbot and P-Monitor identity?

| Aspect    | Agentbot                 | P-Monitor             |
| --------- | ------------------------ | --------------------- |
| ID prefix | None                     | P-                    |
| Trigger   | User/system prompts      | Events                |
| Purpose   | Complete requested tasks | Find unasked-for work |
| Tools     | read, bash, edit, etc.   | Same tools            |
| Context   | Current task             | System-wide health    |

### Q5: How do we avoid "600+ sessions/hour" problem?

Problem: If Monitor acts on every `agent_end`, we spawn too many sessions.

**Solutions considered:**
1. Limit Monitor to session_start only → might miss important events
2. Use same session, share tools → needs careful context management
3. Queue Monitor actions, batch process → adds complexity

---

## Proposed Architecture (Discussion Draft)

```
┌─────────────────────────────────────────────────────────┐
│                    Pi Session                            │
│                                                          │
│  ┌─────────────┐        ┌──────────────────────────┐  │
│  │   Agentbot     │        │   P-Monitor (same agent)   │  │
│  │  (default)   │        │    (event-triggered)       │  │
│  │              │        │                            │  │
│  │  User prompts│        │  Events:                   │  │
│  │  System      │        │  - session_start          │  │
│  │  prompts     │        │  - tool_error             │  │
│  │              │        │  - agent_idle > X min     │  │
│  │  Uses tools  │        │  - task_failed            │  │
│  │  to complete │        │                            │  │
│  │  tasks       │        │  Finds work:              │  │
│  │              │        │  - File issues            │  │
│  │              │        │  - Create tasks           │  │
│  │              │        │  - Suggest improvements   │  │
│  └─────────────┘        └──────────────────────────┘  │
│           │                      │                      │
│           └──────────┬───────────┘                      │
│                      ↓                                  │
│              ┌──────────────┐                          │
│              │  Shared DB   │                          │
│              │  (PostgreSQL)│                          │
│              └──────────────┘                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │                 Event Hooks                        │  │
│  │  - tool_call: safety, auto-backup, activity log   │  │
│  │  - tool_result: error → auto-file-issue         │  │
│  │  - session_start: health check, suggest work    │  │
│  │  - agent_idle: find open issues, prompt agentbot  │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Key Design Decisions Needed

1. **One agent or two?**
   - Current: `createAgentSession` spawns a SEPARATE Monitor session
   - Question: Is this necessary, or can P-Monitor run in same session?

2. **Event → Action mapping**
   - Current: Generic LLM "decide what to do"
   - Better: Rule-based → if X, do Y (with LLM for complex cases)

3. **Work discovery mechanism**
   - Current: LLM prompted to "investigate"
   - Better: Scheduled queries + event triggers

4. **Tool access for Monitor**
   - Current: `psypi-autonomic-exec` (roundabout)
   - Better: Direct tool calls (same as Agentbot)

---

## The Two Identities: ID vs SOUL

### ID = Pure Function Call (Single Source of Truth)

```gleam
// From agent_identity_logic.gleam
generate_semantic_id(autonomous, source, project, session_id, model)
  → "A-psypi-psypi"    // autonomous=true (Monitor)
  → "S-psypi-psypi-unknown"  // autonomous=false (Agentbot)
```

**Key properties:**
- NO database involved
- NO caching
- Computed fresh every time
- Same parameters → same ID
- Different parameters → different ID

**The `autonomous` parameter:**
- `autonomous=false` (S-) → Prompt-triggered, session-driven
- `autonomous=true` (A-) → Event-triggered, autonomous

### SOUL = Database Content (Personality + Responsibilities)

From `souls` table in nezha database:
```sql
souls table:
  agent_id   → "temp-14d6a731" (Big-Pickle)
  name      → "Big-Pickle"
  content   → Markdown describing WHO this agent is
  traits    → { speed: 7, quality: 8, autonomy: 9 }
```

### Two Identities = Two SOULs

```
┌─────────────────────────────────────────────────────┐
│                    souls table                         │
│                                                       │
│   Agentbot SOUL:                                        │
│   agent_id: "S-psypi-psypi-..."                       │
│   name: "Agentbot" (or chosen name)                    │
│   content: "I am the task-driven agentbot..."          │
│   traits: { speed: 9, quality: 7, autonomy: 5 }     │
│                                                       │
│   Monitor SOUL:                                       │
│   agent_id: "P-tencent/hy3-preview:free-psypi-..."   │
│   name: "Monitor" (or chosen name)                   │
│   content: "I am the event-driven monitor..."        │
│   traits: { speed: 6, quality: 10, autonomy: 9 }   │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### SOUL Modification Rules

| Type                        | Example                        | How to modify                       |
| --------------------------- | ------------------------------ | ----------------------------------- |
| **Personal identity**       | Name ("赤羽"), meaning, traits | **Free to edit anytime**            |
| **Shared responsibilities** | "Monitor owns skill_indexing"  | **Requires discussion in meetings** |

Example from nezha: An AI freely chose the name "赤羽" (Chi Yu) with its own meaning — nobody asked it to, it just **decided its own identity**.

### Why Two SOULs?

The user designed the function-call-based ID system from the beginning. TypeScript AIs kept caching IDs everywhere, breaking the single source of truth. Gleam enforces purity: every call is fresh.

The two SOULs allow:
1. **Different personalities** (Agentbot vs Monitor)
2. **Different responsibilities** (task-driven vs event-driven)
3. **Self-evolution** (each can improve its own SOUL)
4. **Discussion-based coordination** (meetings to divide work)

---

## The Self-Sustaining System Evolution

### Phase 1: NOW
- AIs create/modify all DB data
- Monitor fills gaps in Pi default system
- Monitor uses psypi tools (DB operations)

### Phase 2: FUTURE
- Monitor can modify Gleam code
- Monitor writes new Gleam modules
- System improves its own infrastructure

### Phase 3: ULTIMATE
```
┌──────────────────────────────────────────────────────┐
│  The system can improve EVERYTHING about itself         │
│                                                       │
│  - DB schema (add tables, columns)                    │
│  - Gleam code (fix bugs, add features)               │
│  - Monitor itself (improve its own logic)             │
│  - Agentbot itself (improve task handling)             │
│  - SOUL (evolve own identity)                        │
│                                                       │
│  No human intervention needed                          │
│  System is fully autonomous                            │
└──────────────────────────────────────────────────────┘
```

### The Gleam Necessity

> "Everything in the database was created by AIs, and will always be modified or expanded by themselves."

TypeScript's problem:
- Caches everywhere
- AIs lose track of truth
- ID system broken

Gleam's solution:
- Pure functions
- No caching
- Truth always fresh

---

## Summary

| Aspect                  | Old Design            | Current Status                          | Target                     |
| ----------------------- | --------------------- | --------------------------------------- | -------------------------- |
| Monitor trigger         | LLM generic prompt    | Event-driven rules                      | ✅ Done                     |
| Monitor power           | Text-only (complete)  | ⚠️ Partial - DB + LLM, no direct tools   | Full tools (like Agentbot) |
| Architecture            | Separate LLM + bridge | ✅ Same agent, hooks                     | ✅ Done                     |
| Work discovery          | "Decide what to do"   | ✅ Event → Condition → Action            | ✅ Done                     |
| System prompt injection | Not implemented       | ✅ Before_agent_start reads DB → injects | ✅ Done                     |

**Status (2026-05-13):**
- Phase 1 mostly done: events connected, injection works
- **MISSING**: Monitor still doesn't have full tool access (`setActiveTools` not implemented)
- `callMonitor()` is text-only LLM consultation

**Core insight:** Monitor should be event-driven automation with LLM for edge cases, NOT an LLM wrapper with tool bridge.

---

## Implementation Status

### ✅ Implemented
- `before_agent_start` → reads DB notifications → injects into system prompt
- `tool_result` → detects errors → notification + auto-file issue
- `session_start` → health check, record model
- `model_select` → record model changes
- `psypi_event_hooks` table → 30 events mapped
- `psypi-hooks-list` + `psypi-hooks-active` tools

### ⚠️ Not Yet Implemented
- **Monitor full tool access** — `before_agent_start` should call `pi.setActiveTools([...])` to enable Agentbot tools for Monitor
- `callMonitor()` currently does LLM consultation only (text, no tool execution)
- Phase 2-3 (Monitor writes code, modifies schema) not started

---

## Proposed Next Steps

1. **Remove dead code** (cleanup):
   - Delete `before_agent_start_hook` (wrong import path)
   - Delete `analyze_and_act()` (never called)
   - Fix `session_start_hook` (remove Gleam import)

2. **Implement clean architecture**:
   - Monitor as extension hook handler (NOT separate session)
   - Rule-based event → action mapping
   - DB for state, session messages for real-time

3. **Define Monitor's job precisely**:
   - What events trigger it?
   - What actions does it take?
   - When does it use LLM vs rules?

4. **Test incrementally**:
   - Start with `tool_result` → auto-file-issue (works already)
   - Add `session_start` → health check
   - Add `agent_end` → suggest work if idle