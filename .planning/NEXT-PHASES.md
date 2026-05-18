# Next Phases: Monitor Evolution Plan

## Current State (2026-05-12)

- ✅ Identity system (S-/A- IDs with session_id)
- ✅ No fallbacks rule (error if missing session_id)
- ✅ Notification functions in monitor.gleam
- ✅ System prompt injection implemented (before_agent_start hook reads DB notifications)
- ✅ tool_result hook detects errors → creates notifications + auto-files issues
- ✅ model_select hook records model changes
- ✅ psypi_event_hooks table + migration runner
- ✅ psypi-hooks-list + psypi-hooks-active tools for Monitor awareness
- 🔄 Testing with orieg/gemma3-tools:12b-ft-v2 model (downloading)

---

## The Continuous Cycle

**User → Agentbot → Monitor → Agentbot → (User) → Cycling on**

```
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│                    USER (triggers Agentbot)                     │
│                         │                                     │
│                         ▼                                     │
│                    Agentbot works                               │
│                         │                                     │
│                         ▼                                     │
│                    Event fires                                │
│                         │                                     │
│                         ▼                                     │
│                    Monitor acts                               │
│                         │                                     │
│                         ▼                                     │
│              Monitor injects into system prompt                │
│                         │                                     │
│                         ▼                                     │
│                    Agentbot continues                            │
│                         │                                     │
│                         └────────────────────────────────────┐│
│                                         (cycle continues)  │
└─────────────────────────────────────────────────────────────┘
```

**Key insight**: User is part of the cycle. Agentbot is ALWAYS working, Monitor is ALWAYS directing through system prompt. No waiting, no waking up needed.

---

## Phase 1: Connect Events to System Prompt Injection

**Goal**: Every Monitor action → system prompt injection → Agentbot acts

### Tasks

- [x] `before_agent_start` → Read DB notifications → inject into system prompt
- [x] `tool_result` → Detect errors → create notification + auto-file issue
- [x] `session_start` → Health check + record model
- [x] `model_select` → Record model changes to DB
- [ ] Full cycle test (Experiment 4)

### Key Functions

```gleam
// monitor.gleam
get_pending_notifications(agent_id) -> List(Notification)
create_notification(agent_id, priority, title, body)
mark_notifications_read(agent_id)

// extension_generator.gleam - before_agent_start hook
// Reads notifications, injects into systemPrompt
```

---

## Phase 2: Monitor Actions

**Goal**: Monitor actively creates work for Agentbot

### Monitor Actions → System Prompt

| Action           | Trigger         | Injects into System Prompt                 |
| ---------------- | --------------- | ------------------------------------------ |
| Error detected   | tool_result     | "Fix error in X before continuing"         |
| Issue created    | auto_file_issue | "Issue X created, review it"               |
| Health check     | session_start   | "System status: X issues, Y tasks pending" |
| Pattern detected | activity_log    | "You're doing X repeatedly, consider Y"    |
| Skill gap        | task failure    | "Missing skill Z, learn it first"          |

### Future: Monitor Modifies Code

Monitor can:
1. Write to Gleam files
2. Create new Gleam modules
3. Modify existing logic

This requires Monitor to have full tool access.

---

## Phase 3: Autonomous Evolution

**Goal**: System improves itself

### Self-Improvement Areas

| Area           | Current | Future                         |
| -------------- | ------- | ------------------------------ |
| DB schema      | Fixed   | Monitor can add tables/columns |
| Gleam code     | Fixed   | Monitor can modify/extend      |
| Skills         | Fixed   | Monitor can create new skills  |
| Monitor itself | Fixed   | Monitor can improve Monitor    |

### Key Principle

> "Thinking is nothing when is not based on facts"

Monitor acts on DB facts:
- activity_log shows patterns
- issues show problems
- tasks show state

Monitor writes to DB → system evolves.

---

## Identity Evolution

### Current

| ID                    | Trigger      | SOUL            |
| --------------------- | ------------ | --------------- |
| S-psypi-psypi-\<sid\> | User prompts | Agentbot traits |
| A-psypi-psypi-\<sid\> | Events       | Monitor traits  |

### Future: Multiple Agentbots/Monitors

```
S-agentbot1-<sid> → S-agentbot-N-<sid>  (multiple agentbots)
A-monitor1-<sid> → A-autonomic-N-<sid>  (multiple monitors)
```

Each has own SOUL, own responsibilities.

---

## Technical Requirements for Phase 2-3

1. **Monitor must have full tool access**
   - ⚠️ STILL PENDING: `setActiveTools` not implemented
   - Monitor can only use DB + LLM, NOT read/bash/edit/write
   - Needs: read, bash, edit, write (via `pi.setActiveTools()`)

2. **Monitor injects into same session as Agentbot**
   - Current: Monitor runs in hooks
   - Future: Monitor has own session loop
   - Key: System prompt injection bridges both

3. **DB must track Monitor's changes**
   - Version history
   - Rollback capability

---

## Implementation Order

```
Phase 1: Connect Events
  ├── Test injection
  ├── tool_result → inject
  ├── session_start → inject
  ├── model_select → inject
  └── Full cycle

Phase 2: Monitor Actions
  ├── Auto-create issues
  ├── Create tasks
  ├── Inject suggestions
  └── Monitor with full tools

Phase 3: Autonomous Evolution
  ├── Monitor writes code
  ├── Monitor modifies schema
  ├── System self-improves
  └── No human intervention
```

---

## References

- Event mapping: `.planning/EVENT-TASK-MAPPING.md`
- System prompt injection: `.planning/SYSTEM-PROMPT-INJECTION.md`
- Architecture: `.planning/ARCHITECTURE.md`