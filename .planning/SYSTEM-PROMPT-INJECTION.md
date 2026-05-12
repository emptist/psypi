# System Prompt Injection via before_agent_start Hook

## The Gap

```
User prompt → Worker (only wake-up path)
                         ↑
                  [nothing can wake Worker]
                         
Monitor → detects problem → ??? → Worker stays idle
```

Worker only wakes up on:
1. **User prompts** - human types something
2. **System prompts** - loaded at session start, static

Monitor can:
- Detect problems (tool errors, failed tasks)
- Write to DB (issues, tasks, notifications)

But **Monitor cannot wake Worker** - there's no injection mechanism.

---

## Key Points: Identity-Driven Architecture

### 1. Agent ID Required for All Actions

Every action in psypi requires an `agent_id`. No exceptions. Every DB operation, every activity log, every notification must have an agent_id.

### 2. Quick Shifting ID

ID is computed from function call parameters:
```gleam
generate_semantic_id(permanent, source, project, session_id, model)
```

Same function, different parameters → different ID instantly.

### 3. Quick Exchanging Identity

Change ONE parameter → become different identity:

**Convention:**
- Event-driven (hooks): pass `autonomous=true` → Autonomous ID (`A-psypi-psypi`)
- Tool calls (no args): `autonomous` defaults to `false` → Session ID (`S-psypi-psypi-unknown`)

| Prefix | Meaning | Trigger |
|--------|---------|---------|
| `S-` | Session (user-prompt driven) | User prompts |
| `A-` | Autonomous (event-driven) | Hooks, events |

### 4. Differs by SOUL

Two identities, two SOUL entries in `souls` table:
| Agent ID | Name | Traits |
|----------|------|--------|
| `S-psypi-psypi-unknown` | Worker | speed=9, focus=task-completion |
| `A-psypi-psypi` | Monitor | quality=10, focus=system-health |

Same AI, different SOUL → different personality.

### 5. Taking Different Responsibilities

- **Worker**: Task-driven, prompt-driven, completes user requests
- **Monitor**: Event-driven, finds unasked-for work, monitors health

### 6. Act Differently

- Worker: "User asked me to do X" → do X
- Monitor: "Tool error detected" → analyze → act → notify

### 7. One Work, Another Rest

Sequential execution, not parallel:
```
Worker finishes turn → Monitor runs → Worker resumes
```

### 8. System Prompts or Events

Both trigger actions:
- **System prompts**: Inject via `before_agent_start` hook
- **Events**: Hook into tool_result, session_start, agent_end

### 9. Ever Ongoing Running System

Continuous loop:
```
Monitor detects → writes to DB → injects to Worker → Worker acts → Monitor watches
```

---

## Discovered Mechanism: before_agent_start Hook

From Pi SDK (`packages/coding-agent/src/core/extensions/types.ts:1009-1012`):

```typescript
interface BeforeAgentStartEventResult {
  message?: Pick<CustomMessage, "customType" | "content" | "display" | "details">;
  /** Replace the system prompt for this turn */
  systemPrompt?: string;
}
```

From `runner.ts:962-965`:
```typescript
if (result.systemPrompt !== undefined) {
  currentSystemPrompt = result.systemPrompt;
}
```

**The hook CAN modify system prompt!**

Event signature from `types.ts:623-634`:
```typescript
interface BeforeAgentStartEvent {
  type: "before_agent_start";
  prompt: string;
  images?: ImageContent[];
  systemPrompt: string;        // ← Available to hook
  systemPromptOptions: BuildSystemPromptOptions;
}
```

Hook receives `event.systemPrompt` and CAN return modified version.

---

## Architecture: Bridge from Monitor to Worker

```
┌─────────────────────────────────────────────────────────────┐
│                      before_agent_start hook                 │
│                                                             │
│  1. Get agent_id (compute from function call parameters)   │
│  2. Read notifications from DB (by agent_id)               │
│  3. If pending → return { systemPrompt: base + urgent }    │
│  4. If empty → return nothing (normal flow)                 │
│                        ↓                                     │
│              Worker receives modified system prompt         │
│                        ↓                                     │
│              Worker acts on Monitor's notification          │
└─────────────────────────────────────────────────────────────┘

                           ↑ (writes)
┌─────────────────────────────────────────────────────────────┐
│                         Monitor                               │
│                                                             │
│  tool_result hook (on error)                                │
│         ↓                                                   │
│  create_notification(agent_id, priority, title, body)        │
│         ↓                                                   │
│  DB receives: notifications table                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### notifications table (created)

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id TEXT NOT NULL,           -- Target worker ID
  priority TEXT DEFAULT 'medium',   -- low, medium, high, critical
  title TEXT NOT NULL,              -- Short description
  body TEXT NOT NULL,               -- Full message
  created_at TIMESTAMP DEFAULT NOW(),
  read_at TIMESTAMP                 -- Marked after delivery
);
```

### Agent ID Convention

- **Worker** (Session-driven): `S-psypi-psypi-unknown` (autonomous=false)
- **Monitor** (Autonomous-driven): `A-psypi-psypi` (autonomous=true)

Same AI, different ID based on `autonomous` parameter:
- `S-` = Session (prompt-driven)
- `A-` = Autonomous (event-driven)

---

## Implementation: New before_agent_start Hook

```javascript
pi.on('before_agent_start', async (event, ctx) => {
  // 1. Get Worker agent ID (same computation as psypi-my-id tool)
  const identity = await agent_identity_get_resolved_identity(
    false,      // permanent = false → Worker
    _sessionId, // session ID from session_start
    'psypi',
    '',
    '',
    'psypi',
    ''
  );
  const r = unwrapGleamResult(identity);
  if (!r.ok) return;

  // 2. Read pending notifications for Worker
  const { get_pending_notifications } = await import('./build/dev/javascript/psypi/monitor.mjs');
  const notifs = await get_pending_notifications(r.value.id);
  const n = unwrapGleamResult(notifs);

  if (!n.ok || n.value.length === 0) return;

  // 3. Format notifications for injection
  const urgent = n.value
    .map(notif => `[${notif.priority.toUpperCase()}] ${notif.title}: ${notif.body}`)
    .join('\n');

  // 4. Inject into system prompt
  return {
    systemPrompt: event.systemPrompt + '\n\n' +
      '=== MONITOR ALERT ===\n' + urgent + '\n' +
      '=== END MONITOR ALERT ===\n' +
      'Address the above alerts before continuing your normal task.'
  };
});
```

---

## Experiment Plan

### Experiment 1: Hook Return Value

**Goal**: Verify hook return modifies system prompt
**Steps**:
1. Simple hook: return `{ systemPrompt: "INJECTED: " + event.systemPrompt }`
2. Send any message to Worker
3. Check if "INJECTED:" appears in context

### Experiment 2: DB Read

**Goal**: Can hook read from PostgreSQL?
**Steps**:
1. Create test notification in DB
2. Hook calls Gleam function → reads notifications
3. Check console for notification content

### Experiment 3: Full Injection

**Goal**: Does injected prompt reach Worker?
**Steps**:
1. Monitor creates notification via DB direct insert
2. User sends any message to Worker
3. Worker should acknowledge Monitor's alert

### Experiment 4: Round-trip

**Goal**: Full Monitor → Worker communication
**Steps**:
1. tool_result hook detects error
2. Creates notification in DB
3. before_agent_start hook injects
4. Worker responds to alert

---

## Key Files to Modify

| File | Change |
|------|--------|
| `src/extension_generator.gleam` | Rewrite `before_agent_start_hook()` to return systemPrompt |
| `src/monitor.gleam` | Add `get_pending_notifications(agent_id)` |
| `src/monitor_ai.gleam` | Add `create_notification()` for Monitor |
| `extension.js` | Regenerated output |

---

## Edge Cases

1. **Multiple notifications**: Concatenate all (limit ~2000 chars)
2. **Empty notifications**: Return nothing, normal flow continues
3. **High priority**: Mark clearly, prepend to injection
4. **Rate limiting**: Don't re-inject same notification within 5 minutes
5. **Persistence**: Mark `read_at` after successful injection

---

## Risks

1. **System prompt too large**: Limit notification injection to ~2000 chars
2. **Hook blocks Worker**: Keep async operations minimal
3. **Race condition**: Notifications might arrive during processing
4. **Missing session ID**: Handle case where _sessionId is null

---

## Status

- [x] Renamed: `permanent` → `autonomous`
- [x] Renamed: `P-` prefix → `A-` (Autonomous)
- [x] Updated all references in Gleam source:
  - `src/agent_identity_logic.gleam`
  - `src/agent_identity.gleam`
  - `src/identity.gleam`
  - `src/context.gleam`
- [x] Updated SOUL entry: `A-psypi-psypi`
- [x] Mechanism discovered in Pi SDK
- [x] `BeforeAgentStartEventResult.systemPrompt` confirmed
- [x] notifications table created
- [x] monitor.gleam: added notification functions
- [x] Experiment 1 ready (simple injection test)
- [ ] Test: simple injection (Experiment 1)
- [ ] Test: DB read (Experiment 2)
- [ ] Test: full round-trip (Experiment 4)

---

## References

- Pi SDK: `packages/coding-agent/src/core/extensions/types.ts`
- Runner: `packages/coding-agent/src/core/extensions/runner.ts:960-988`
- Session: `packages/coding-agent/src/core/agent-session.ts:1093-1094`

---

## Experiment (Run After Build)

```bash
# Run psypi (NOT bare `pi`)
psypi
```

Send any message. Look for `[MONITOR-INJECTED-...]` marker in Worker's response.

**Why `psypi` not `pi`?**
- `pi` - bare Pi runtime, no psypi extension
- `psypi` - Pi + psypi extension (Gleam tools, identity, Monitor)