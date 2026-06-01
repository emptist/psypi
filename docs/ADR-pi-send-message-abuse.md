# ADR: pi_send_message Abuse — A-bot Is Castrated

## Status
Proposed

## Date
2026-06-01

## Context

`pi_send_message()` is the FFI wrapper around Pi SDK's `pi.sendMessage()`. It is used in 5 call sites across the codebase. Currently it hardcodes `triggerTurn: false`, which contradicts both the documented design and the actual needs of the A/S system.

The user had to temporarily set `triggerTurn: false` to stop A-bot's raw LLM thinking from immediately waking S-bot. This is a symptom of a deeper problem: **A-bot is 阉割了 (castrated)** — it can only read from the database and send text messages. It cannot write anything. It cannot produce artifacts. It is a text passthrough, not an agent.

## The Real Problem: A-bot Is Castrated

### Evidence

`hook_on_agent_end.gleam` — the ENTIRE `run_a_bot()` function:

```
1. Read soul from DB          (a_db_reader.read_soul_from_db)
2. Read jobs from DB          (a_db_reader.read_a_jobs_from_db)
3. Read project state from DB (a_db_reader.read_project_state_from_db)
4. Read last session time     (a_db_reader.get_last_a_session_at)
5. Get recent commits         (exec_sync "git log")
6. Build prompts              (a_prompt_builder)
7. Call LLM                   (call_monitor)
8. Send LLM response as text  (pi_send_message)
```

**That's it.** A-bot has ZERO write operations. No `inter_review.save()`. No `issue_add`. No `task_add`. No database writes at all. A-bot is a read-only pipeline that asks an LLM what to think and forwards the text to S.

### What This Means

1. **A-bot cannot file its findings** — When A discovers a problem, it can only tell S about it in natural language. It cannot create an issue, write a review, or record a finding. The finding exists only in the message text, which scrolls away.

2. **A-bot cannot track its own work** — A has no memory of what it did last cycle. It reads `last_a_session_at` from config, but not its own previous reviews or findings. Every cycle starts from scratch.

3. **A-bot's LLM output is raw thinking** — `call_monitor()` returns whatever the LLM says. Sometimes it's a structured review. Sometimes it's stream of consciousness. Sometimes it hallucinates `sqlite3` commands. There's no structure, no validation, no artifact.

4. **With `triggerTurn: true`, this raw thinking gets injected directly into S-bot's conversation** — S sees A's half-formed thoughts and tries to respond to them. This is the "stupid behavior" the user observed.

### Why triggerTurn:true Is Wrong FOR THIS A-BOT

The documented design says `triggerTurn: true`. This would be correct IF A-bot produced a clean, structured artifact (like an inter-review with an ID). But A-bot doesn't produce anything — it just forwards LLM text.

With `triggerTurn: true` and the current castrated A-bot:

```
1. S finishes work → agent_end fires
2. Debounce timer fires → A starts working
3. A calls call_monitor() → LLM returns raw thinking text
4. A sends raw text with triggerTurn:true
5. Pi SDK calls agent.prompt(raw_text) → S starts a new turn
6. S sees A's raw thinking in its conversation
7. S tries to respond to A's half-baked analysis
8. S may call psypi-my-id, or try to act on A's incomplete findings
9. S finishes → agent_end fires → debounce starts → A wakes again
10. A sees the same state (nothing changed in DB) → sends same raw text
```

This is NOT an "infinite loop" (I was wrong about that). It's worse — it's a **degenerate dialogue** where A sends raw thoughts and S responds to them, but nothing gets recorded, nothing gets tracked, and nothing improves. The system talks to itself without producing value.

### The Conversation Dump Proves This

From the user's saved conversation (`A-bot-thinking.md`):

```
My ID is S-psypi-openrouter-openrouter/owl-alpha.
I am Somatic Bot (S)...

[A-agentbot] Sending wake-up message...

[A-agentbot] [A-agentbot]
I need to perform my Check duties. Let me start by reading the soul/jobs...
```

S-bot's conversation shows A-bot's raw LLM output mixed in. S then tries to respond to A's thinking, creating confusion. A's output includes self-corrections ("Wait — I see the issue"), dead ends, and hallucinated `sqlite3` commands.

## Pi SDK sendMessage API (Ground Truth)

Source: `agent-session.ts:1260-1319`

```typescript
async sendCustomMessage(message, options?) {
  if (options?.deliverAs === "nextTurn") {
    this._pendingNextTurnMessages.push(appMessage);
  } else if (this.isStreaming) {
    if (options?.deliverAs === "followUp") {
      this.agent.followUp(appMessage);
    } else {
      this.agent.steer(appMessage);
    }
  } else if (options?.triggerTurn) {
    await this.agent.prompt(appMessage);  // ← STARTS NEW S TURN
  } else {
    this.agent.state.messages.push(appMessage);  // ← JUST APPENDS
  }
}
```

When `triggerTurn: true` and agent is idle: `agent.prompt(appMessage)` starts a **completely new agent turn**. S-bot will process the message and respond.

When `triggerTurn: false` and agent is idle: message is appended to session state. S-bot sees it on the next turn (when human types), but does NOT respond immediately.

## Current Call Sites (5 total)

### 1. hook_on_agent_end.gleam — A-bot's main wake-up (line 118)

```gleam
pi_send_message(pi, "autonomic-wakeup", tagged, "persistent")
```

**Current**: `triggerTurn: false` — message appended, S doesn't respond until human types.

**Problem**: A's findings are invisible until next human interaction.

**Deeper problem**: A's "findings" are just raw LLM text, not structured artifacts.

### 2-4. Error notifications (hook_on_agent_end, hook_on_tool_call, hook_on_tool_result)

All use `triggerTurn: false`. **Correct** — errors should not wake S.

### 5. command_listen.gleam — Human-to-A direct message (line 35)

```gleam
pi_send_message(pi, "autonomic-wakeup", message, "persistent")
```

**Current**: `triggerTurn: false` — **WRONG**. Human explicitly wants S to respond.

## The Inter-Review Gate

**Key insight (from user)**: `triggerTurn: true` should ONLY be allowed AFTER A-bot has written an inter-review to the database. This solves both problems:

1. **A-bot is no longer castrated** — it can write inter-reviews, creating real artifacts
2. **triggerTurn:true is safe** — S wakes up to a concrete review with an ID, not raw thinking
3. **The dialogue is productive** — S responds to a structured review, not stream of consciousness

```
Current flow (castrated):
  call_monitor() → raw LLM text → pi_send_message(triggerTurn: false)
  Result: A's findings are invisible until human types

Proposed flow (inter-review gate):
  call_monitor() → raw LLM text
    → parse into structured review (summary, score, findings, suggestions)
    → inter_review.save(summary, score, findings, suggestions)
    → on success: pi_send_message(triggerTurn: true, "Review ID: xxx")
    → on failure: pi_send_message(triggerTurn: false, error notification)
  Result: A produces an artifact, S wakes to a concrete review
```

**Why this works**:
- A can't send `triggerTurn: true` without first writing to DB
- The DB write is atomic — either it succeeds (review exists) or fails (no trigger)
- S always has something concrete to respond to (a review with an ID)
- A's next cycle can check: "Did S address my review?" — it has a review ID to look up
- The system produces value every cycle: a review artifact in the database

**Implementation challenge**: `call_monitor()` returns free-form text. To write an inter-review, A needs structured output. Options:

1. **Parse the LLM response into structured fields** — fragile, LLM output is unpredictable
2. **Two LLM calls**: one for analysis (free-form), one for structured review (JSON output)
3. **Change system prompt to require JSON output** — breaking change
4. **Separate `call_monitor_structured()` function** — cleanest, no impact on existing flow

## Proposed Solution: Inter-Review Gate + Typed Message Dispatch

```gleam
pub type MessageIntent {
  InformOnly
  WakeSAfterReview(review_id: String)
  QueueForNextTurn
}
```

```javascript
export function pi_send_message(pi, customType, content, display, intent) {
  switch (intent) {
    case "InformOnly":
      pi.sendMessage({...}, { triggerTurn: false });
      break;
    case "WakeSAfterReview":
      pi.sendMessage({...}, { triggerTurn: true, deliverAs: "followUp" });
      break;
    case "QueueForNextTurn":
      pi.sendMessage({...}, { deliverAs: "nextTurn" });
      break;
  }
}
```

| Call Site | Intent | triggerTurn |
|-----------|--------|-------------|
| agent_end wake-up (review saved) | `WakeSAfterReview` | true |
| agent_end wake-up (no review saved) | `QueueForNextTurn` | false |
| agent_end errors | `InformOnly` | false |
| tool_call errors | `InformOnly` | false |
| tool_result errors | `InformOnly` | false |
| command_listen | `WakeSAfterReview` | true |

**The key rule**: `WakeSAfterReview` can ONLY be used after a successful `inter_review.save()`. The `review_id` parameter must come from the save result. This is enforced by the type system.

## What A-bot Needs To Become

Currently A-bot is a castrated read-only passthrough. To implement the inter-review gate, A-bot needs to become a **write-capable agent**:

| Current A-bot | Needed A-bot |
|---------------|-------------|
| Read soul from DB | Read soul from DB |
| Read jobs from DB | Read jobs from DB |
| Read project state from DB | Read project state from DB |
| Read last session time | Read last session time + last inter-review |
| Call LLM (free-form) | Call LLM (structured output) |
| Send raw text to S | **Write inter-review to DB** → Send review ID to S |
| No memory between cycles | Read previous inter-reviews for follow-up |

## Consequences

- **Positive**: A-bot produces real artifacts (inter-reviews in database)
- **Positive**: `triggerTurn: true` is safe — S wakes to a structured review, not raw thinking
- **Positive**: command_listen works correctly (human explicitly wants S to respond)
- **Positive**: A-bot has memory between cycles (can look up previous reviews)
- **Positive**: The PDCA closed loop works: review → issue → task → review follow-up
- **Risk**: Parsing LLM output into structured fields is fragile
- **Risk**: Two LLM calls per cycle increases cost and latency
- **Mitigation**: Use JSON mode for structured output, or a separate `call_monitor_structured()`

## Related Issues

| Issue ID | Title | Relationship |
|----------|-------|-------------|
| `5e0e4283` | A-bot hallucinates SQL column/table names | A's context lacks DB schema — same root cause (A is castrated) |
| `da3b3fd8` | MASS DATA LOSS from S-bot deletion | A's Check should have caught it — but A can't write findings |
| Review finding #9 | hook_on_agent_end.gleam has 8-level nested promise chains | Refactoring needed to add inter-review write step |

## Related Documentation

- [AS-COMMUNICATION.md](./AS-COMMUNICATION.md) — documents `triggerTurn: true` (correct design, but A-bot can't support it yet)
- [INVESTIGATION-A-BOT-CONTEXT-PROBLEMS.md](./INVESTIGATION-A-BOT-CONTEXT-PROBLEMS.md) — sqlite3 hallucination, terminal access hallucination
- [AGENTS.md](../AGENTS.md) line 335 — documents `triggerTurn: true` for A→S communication
- Pi SDK source: `agent-session.ts:1260-1319` — ground truth for sendMessage behavior
