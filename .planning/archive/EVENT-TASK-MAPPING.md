# Pi Events → Agentbot/Monitor Task Mapping

## The Cycle

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
│               Monitor injects into system prompt              │
│                         │                                     │
│                         ▼                                     │
│                    Agentbot continues                            │
│                         │                                     │
│                         └──────────────────────────────────────┘
│                                          (cycle continues)    │
└─────────────────────────────────────────────────────────────┘
```

**Key insight**:
- User triggers Agentbot (user input)
- Monitor DIRECTS Agentbot through system prompt
- User can also trigger at any point (input event)
- Agentbot is ALWAYS working, Monitor is ALWAYS directing

### Session Events

| Event                    | When              | Agentbot Task   | Monitor Task                           |
| ------------------------ | ----------------- | --------------- | -------------------------------------- |
| `session_start`          | Session begins    | Load context    | Initialize, health check, record model |
| `session_before_switch`  | Before switch     | Save state      | Validate switch safe                   |
| `session_before_fork`    | Before fork       | Prepare         | Monitor fork                           |
| `session_before_compact` | Before compaction | Summarize       | Review compaction                      |
| `session_compact`        | Compaction runs   | Receive summary | Monitor quality                        |
| `session_before_tree`    | Before tree nav   | Prepare         | Validate target                        |
| `session_tree`           | Tree navigation   | Navigate        | Log navigation                         |
| `session_shutdown`       | Session ends      | Save state      | Final report                           |

### Agent Events

| Event                | When              | Agentbot Task | Monitor Task             |
| -------------------- | ----------------- | ------------- | ------------------------ |
| `before_agent_start` | Before agent loop | Load tasks    | **Inject notifications** |
| `agent_start`        | Agent loop starts | Begin work    | Log start                |
| `agent_end`          | Agent loop ends   | Summarize     | Log end, analyze         |
| `turn_start`         | Turn starts       | Begin turn    | Log turn                 |
| `turn_end`           | Turn ends         | Complete turn | Log turn, analyze        |
| `context`            | Context changes   | Adapt         | Detect changes           |

### Message Events

| Event            | When            | Agentbot Task | Monitor Task |
| ---------------- | --------------- | ------------- | ------------ |
| `message_start`  | Message starts  | Process       | Log          |
| `message_update` | Message updates | Receive       | Log          |
| `message_end`    | Message ends    | Complete      | Analyze      |

### Tool Events

| Event                   | When         | Monitor Task                         | Monitor Injects into System Prompt   |
| ----------------------- | ------------ | ------------------------------------ | ------------------------------------ |
| `tool_execution_start`  | Tool starts  | Log                                  | -                                    |
| `tool_execution_update` | Tool updates | Monitor progress                     | -                                    |
| `tool_execution_end`    | Tool ends    | Log                                  | -                                    |
| `tool_call`             | Before tool  | **Safety check, auto-backup**        | Warnings if dangerous                |
| `tool_result`           | After tool   | **Error detection, auto-file issue** | "File issue X was created, check it" |

### Provider Events

| Event                     | When               | Monitor Task               | Monitor Injects into System Prompt |
| ------------------------- | ------------------ | -------------------------- | ---------------------------------- |
| `before_provider_request` | Before LLM call    | Log, debug                 | -                                  |
| `after_provider_response` | After LLM response | **Log, rate limit detect** | "Rate limited, throttle requests"  |

### Model Events

| Event                   | When             | Agentbot Task | Monitor Task            |
| ----------------------- | ---------------- | ------------- | ----------------------- |
| `model_select`          | Model changes    | Adapt         | **Record model change** |
| `thinking_level_select` | Thinking changes | Adapt         | Log                     |

### User Events

| Event       | When       | Agentbot Task | Monitor Task |
| ----------- | ---------- | ------------- | ------------ |
| `user_bash` | Bash input | Execute       | Log          |
| `input`     | User input | Process       | Log          |

### Render Events

| Event          | When               | Agentbot Task | Monitor Task |
| -------------- | ------------------ | ------------- | ------------ |
| `renderCall`   | Tool call render   | -             | UI update    |
| `renderResult` | Tool result render | -             | UI update    |

---

## Implementation Priority

### Phase 1: Essential (Agentbot + Monitor basic)

- [ ] `session_start` → Monitor: record model, health check
- [ ] `before_agent_start` → Monitor: inject notifications
- [ ] `tool_result` → Monitor: error detection, auto-file issue
- [ ] `tool_call` → Monitor: safety check, auto-backup

### Phase 2: Complete Coverage

- [ ] `agent_start` / `agent_end` → Log activity
- [ ] `turn_start` / `turn_end` → Log turns
- [ ] `session_shutdown` → Agentbot: save state, Monitor: final report
- [ ] `model_select` → Monitor: record model changes

### Phase 3: Full Event Hookup

- [ ] `message_*` events → Message logging
- [ ] `tool_execution_*` events → Detailed tool monitoring
- [ ] `session_compact` → Compaction monitoring
- [ ] `user_bash` / `input` → User action logging

### Phase 4: Advanced

- [ ] `context` → Context change detection
- [ ] `before_provider_request` → Request debugging
- [ ] `after_provider_response` → Response analysis

---

## Current Implementation Status (2026-05-12)

| Event                | Agentbot | Monitor                                                   | System Prompt Injection |
| -------------------- | -------- | --------------------------------------------------------- | ----------------------- |
| `session_start`      | ✅        | ✅ health check, record model                              | ✅ session info          |
| `before_agent_start` | ✅ work   | ✅ **inject notifications from DB**                        | ✅ full bridge           |
| `agent_start`        | -        | ✅ log                                                     | -                       |
| `agent_end`          | -        | ✅ log, analyze                                            | -                       |
| `tool_call`          | ✅        | ✅ safety, activity log, auto-backup                       | ✅ warnings              |
| `tool_result`        | ✅ result | ✅ **detect errors, create notification, auto-file issue** | ✅ "check issue X"       |
| `model_select`       | ✅ adapt  | ✅ record model change to DB                               | -                       |
| Others               | ❌        | ❌                                                         | ❌                       |

---

## Monitor's Primary Function

**Monitor does not just watch. Monitor DIRECTS.**

1. **Detects** problems (errors, patterns, issues)
2. **Creates** tasks/issues (auto-file)
3. **Injects** work into Agentbot's system prompt
4. **Agentbot continues** based on Monitor's direction
5. **Cycle repeats**

This is NOT passive monitoring. This is active workflow direction through system prompt injection.

---

## Key Insight

Every Pi event is an opportunity for Agentbot or Monitor to act. The system is inherently event-driven - we just need to hook into each event and define the action.

**Goal**: Map every event → Agentbot or Monitor task → DB action

## psypi_event_hooks Table

Monitor reads this table to know which events to act on. Table persists across sessions.

```sql
-- Run migrations:
gleam run -m simple_migrate
```

New hooks added to `src/migrations/003_create_event_hooks_table.sql`:
- 29 Pi events mapped (session, agent, tool, model, user, render)
- 7 are `active` with `injection_enabled=true`
- Monitor can modify hook status via `psypi-hooks-list` / `psypi-hooks-active` tools

This creates a complete event-driven system where:
- Agentbot acts on user-prompted events
- Monitor acts on all other events
- No polling, no timers needed