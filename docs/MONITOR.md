# Monitor - Autonomous System Guardian for psypi

**Monitor = "immune system" of psypi** - a set of Gleam functions + Pi tools + event hooks identified by an autonomous ID.

## What is Monitor?

Monitor is NOT a separate agent process. It's simply:
- `monitor.gleam` - Functions (notifications, model config, health)
- `monitor_ai.gleam` - AI functions (suggestions, stats, alerts)
- Pi tools (`psypi-monitor-*`, `psypi-commit`, `psypi-monitor-consult`)
- Event hooks in `extension.js` (tool_call, session_start, before_agent_start, etc.)

All run under an **autonomous identity** (from `get_resolved_identity(autonomous=true, ...)` → `A-psypi-psypi`).

**Core principle:** No spawn, no separate loop, no periodic tasks. Just functions that happen to share an autonomous ID.

---

## 3 Modes of Operation

```
                     ┌─────────────────────────────────────────┐
                     │              MONITOR                    │
                     │  (single brain, 3 modes)               │
                     └─────────────────────────────────────────┘
                                         ↑
          ┌──────────────────────────────┴───────────────────────────────┐
          │                                                            │
     ╔════╪═══════════╗                            ╔═══════════════════╪═══╗
     ║ 1. SILENT      ║                            ║ 3. END OF WORKFLOW ║
     ║ (always on)    ║                            ║ (e.g. git commit)  ║
     ║                ║                            ║                    ║
     ║ - health       ║                            ║ inter_review →    ║
     ║ - skills       ║                            ║ Monitor LLM       ║
     ║ - cleanup      ║                            ║ → score/feedback  ║
     ║ - learning     ║                            ║ → pass/fail       ║
     ║ - safety       ║                            ║ → git commit      ║
     ║ - auto-backup  ║                            ╚════════════════════╝
     ╚════════════════╝
                                         ↑
                                         │
          ┌──────────────────────────────┴────────────┐
          │ 2. MIDDLE OF WORKFLOW (proactive)        │
          │                                          │
          │ Worker: "Should I use array or dict?"   │
          │ psypi-monitor-consult → Monitor          │
          └──────────────────────────────────────────┘
```

### Mode 1: Silent (Always Running)

Monitor watches and maintains the system via event hooks:

| Event | What Monitor Does |
|-------|-------------------|
| `tool_call` | Safety blocking, auto-backup, activity logging |
| `session_start` | Initialize session |
| `before_agent_start` | Inject context/memories |
| `agent_start` | Log agent start |
| `agent_end` | Summarize work done |
| `tool_result` | Analyze results, error detection |

**Safety blocking:** Prevents dangerous operations:
- Spawning Pi/psypi (infinite loop)
- `rm -rf` (recursive delete)
- `git push --force` (force push)
- `DROP TABLE` (destructive)
- `DELETE FROM WHERE` without LIMIT

### Mode 2: Middle of Workflow (Proactive)

Worker proactively consults Monitor:

```bash
psypi-monitor-consult "Should I use array or dict?"
psypi-monitor-consult "What do you think about this approach?"
```

Returns LLM-generated advice using same model as worker.

### Mode 3: End of Workflow (Triggered)

Inter-review before git commit:

```
Worker writes code
        ↓
psypi-commit "my commit message" (no ID yet)
        ↓
Monitor reviews → PASS/FAIL + score + UUID
        ↓
   ┌────┴────┐
   ↓         ↓
 FAIL       PASS + UUID
   ↓         ↓
Worker      psypi-commit --review-id=<UUID> "message"
fixes            ↓
   ↓      Monitor verifies ID → git commit
retry ──────────────────────────────→
```

---

## Pi Tools

| Tool | Description |
|------|-------------|
| `psypi-my-id` | Get current agent ID |
| `psypi-monitor-id` | Get monitor/partner permanent ID |
| `psypi-monitor-health` | Get system health metrics |
| `psypi-monitor-alerts` | Get active alerts (failed tasks, open issues) |
| `psypi-monitor-stats` | Get model quality (review scores, response times, failure rate) |
| `psypi-monitor-suggest` | Get work suggestions (open issues, stale tasks, pending skills) |
| `psypi-monitor-consult` | Consult Monitor for difficult decisions (LLM) |
| `psypi-commit` | Commit with inter-review (Mode 3) |

---

## Implementation Details

### Key Files

| File | Purpose |
|------|---------|
| `src/monitor.gleam` | Model configuration (get/set) |
| `src/monitor_ai.gleam` | Functions: health, stats, suggestions, alerts |
| `src/extension_generator.gleam` | Generates extension.js with tools + hooks |
| `extension.js` | Generated output (auto-regenerated) |

### How It Works

1. **Event hooks** - Monitor watches all interactions via Pi event hooks
2. **Safety** - Blocks dangerous operations before they execute
3. **Auto-backup** - Saves file versions before edit/write
4. **LLM consultation** - Uses `callMonitor()` which uses same model as worker
5. **Inter-review** - Reviews code before commit with strict ID system

### callMonitor() Function

```javascript
async function callMonitor(messages, systemPrompt) {
  if (!ctx.model) throw new Error('No model available');
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!auth.ok || !auth.apiKey) throw new Error(auth.error || 'No API key');
  const response = await complete(
    ctx.model,
    { systemPrompt, messages },
    { apiKey: auth.apiKey, headers: auth.headers }
  );
  return response.content.filter(c => c.type === 'text').map(c => c.text).join('\n');
}
```

---

## Key Insights

### Pre-commit is Learning Opportunity

> Pre-commit review is MORE IMPORTANT than the commit itself. It's not just a gate - it's a learning opportunity.

Each commit is a "cell" being quality-checked. Monitor not only reviews code but:
- Identifies patterns suggesting worker needs education
- Provides `EDUCATION_SUGGESTION` in feedback
- Tracks learning patterns for improvement

### No Separate Immune System

> There is no standalone immune system separated from every cell - just as there is no separate Monitor from the workflow. Every interaction IS the immune system.

Monitor IS the workflow. It's not a separate process - it's the permanent identity that watches, learns, and improves.

### Event-Driven Only

Monitor has no periodic polling. Everything is triggered by:
- Worker actions (tool calls)
- Workflow boundaries (commit)
- Explicit requests (psypi-monitor-consult)

---

## Future Improvements

| Feature | Status |
|---------|--------|
| Statistics (model quality) | ✅ Done |
| Self-design (find work) | ✅ Done |
| Instructions (teach tools/skills) | 🔲 Future |
| Learn mistakes (track patterns) | 🔲 Future |
| Proactive improvement suggestions | 🔲 Future |

## Future Improvements

| Feature | Status |
|---------|--------|
| Statistics (model quality) | ✅ Done |
| Self-design (find work) | ✅ Done |
| System prompt injection (notifications) | 🔲 In Progress |
| Autonomous code modification | 🔲 Future |
| Learn mistakes (track patterns) | 🔲 Future |

---

## The Complete Chain: ID → Identity → Behavior → Phase → Event → Next Run

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. REQUIREMENT OF ID                                                        │
│     "Every action requires an agent_id. No exceptions."                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. IDENTITY COMPUTATION                                                      │
│     generate_semantic_id(autonomous, ...) → A-psypi-psypi                   │
│     Pure function, no DB, no cache — computed fresh every time               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. IDENTITIES (SOUL)                                                        │
│     A-psypi-psypi (Monitor) → SOUL from souls table                          │
│     { name: "Monitor", traits: { quality: 10, autonomy: 9 }, content: ... }  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  4. BEHAVIORS AND ACTIONS                                                     │
│     • Event-driven (autonomous=true)                                         │
│     • Detects tool errors, system health                                     │
│     • Creates notifications for Worker                                       │
│     • Reviews code, consults on decisions                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  5. TIME PHASES (Sequential Execution)                                       │
│                                                                              │
│     Phase 1: Worker acts on user prompt (S-)                                 │
│           ↓                                                                  │
│     Phase 2: Monitor detects events (A-) while Worker rests                   │
│           ↓                                                                  │
│     Phase 3: before_agent_start injects notifications into Worker           │
│           ↓                                                                  │
│     Loop: Worker → Monitor → Worker                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  6. EVENTS / PROMPTS                                                         │
│                                                                              │
│     Prompt path: User → Worker (S-) → Tool execution                        │
│     Event path:  Hook fires → Monitor (A-) → writes notification            │
│                  ↓ before_agent_start → Worker receives (S-)                │
│                                                                              │
│     Key: autonomous=true for hooks, autonomous=false for tools              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  7. NEXT RUN                                                                 │
│     User prompt or event triggers the cycle again                            │
│     ID is ALWAYS computed fresh — never cached or stored                    │
│                                                                              │
│     ┌──────────────────────────────────────────────────────────────────┐     │
│     │  User Prompt / Event                                             │     │
│     │       │                                                          │     │
│     │       ▼                                                          │     │
│     │  generate_semantic_id(autonomous, ...)  ← Fresh!                │     │
│     │       │                                                          │     │
│     │       ▼                                                          │     │
│     │  Lookup SOUL from DB                                             │     │
│     │       │                                                          │     │
│     │       ▼                                                          │     │
│     │  Behavior based on SOUL                                          │     │
│     │       │                                                          │     │
│     │       ▼                                                          │     │
│     │  Write to DB (activity_log, notifications)                       │     │
│     │       │                                                          │     │
│     │       ▼                                                          │     │
│     │  Next run ← ─────────────────────────────────────────────────────│     │
│     └──────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*Updated: 2026-05-12*