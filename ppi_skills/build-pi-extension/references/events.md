# Pi Event Lifecycle Cheat Sheet

## Full Lifecycle

```
pi starts
  ├─► session_start { reason: "startup" }
  └─► resources_discover { reason: "startup" }
      │
      ▼
user sends prompt ─────────────────────────────────────────┐
  ├─► input (intercept/transform/handle)                   │
  ├─► before_agent_start (inject msg, modify prompt)       │
  ├─► agent_start                                          │
  │   ┌─── turn (repeats) ───┐                            │
  │   ├─► turn_start         │                            │
  │   ├─► context (modify messages)                        │
  │   ├─► before_provider_request                          │
  │   │   ├─► tool_execution_start                         │
  │   │   ├─► tool_call (can BLOCK)                        │
  │   │   ├─► tool_execution_update                        │
  │   │   ├─► tool_result (can MODIFY)                     │
  │   │   └─► tool_execution_end                           │
  │   └─► turn_end                                         │
  └─► agent_end                                            │
                                                           │
user sends another prompt ◄────────────────────────────────┘

/new, /resume → session_before_switch → session_shutdown → session_start
/fork, /clone → session_before_fork  → session_shutdown → session_start
/compact     → session_before_compact → session_compact
exit         → session_shutdown
```

## Key Events for Extensions

### Most Commonly Used

| Event | When | Can | Typical Use |
|---|---|---|---|
| `session_start` | Session begins | Init state | Reconstruct state, register dynamic tools |
| `session_shutdown` | Session ends | Cleanup | Close connections, save state |
| `before_agent_start` | Before LLM call | Inject message, modify prompt | Add context, inject directives |
| `tool_call` | Before tool executes | **Block**, mutate args | Permission gates, argument patching |
| `tool_result` | After tool executes | **Modify result** | Post-process, enrich output |
| `agent_end` | After agent finishes | React | Trigger follow-up work |
| `input` | User types | Intercept, transform, handle | Custom input processing |

### Less Common but Useful

| Event | When | Can | Typical Use |
|---|---|---|---|
| `context` | Before each LLM call | Modify messages | Prune/filter conversation |
| `turn_start` / `turn_end` | Each LLM turn | React | Logging, turn-level logic |
| `message_start` / `message_end` | Message lifecycle | Replace message (end) | Custom message rendering |
| `model_select` | Model changes | React | Update UI, model-specific init |
| `user_bash` | User runs `!` command | Intercept, wrap | SSH, sandboxing |
| `before_provider_request` | Before API call | Replace payload | Debug logging, payload rewrite |
| `after_provider_response` | After API response | Inspect | Rate limit detection |

## Event Return Values

| Event | Return | Effect |
|---|---|---|
| `tool_call` | `{ block: true, reason }` | Prevents tool execution |
| `tool_result` | `{ content, details, isError }` | Patches tool result |
| `before_agent_start` | `{ message, systemPrompt }` | Injects message / modifies prompt |
| `context` | `{ messages }` | Replaces messages for LLM |
| `input` | `{ action: "handled" }` | Skips agent entirely |
| `input` | `{ action: "transform", text }` | Rewrites input |
| `session_before_*` | `{ cancel: true }` | Cancels the action |

## Parallel Tool Execution Notes

- `tool_call` handlers run sequentially (in assistant source order) during preflight
- Tool **execution** is concurrent
- `tool_result` and `tool_execution_end` may interleave in completion order
- Final `toolResult` message events are emitted in assistant source order
- `tool_call` does NOT see sibling tool results from the same assistant message
