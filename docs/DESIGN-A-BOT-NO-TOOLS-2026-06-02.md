# Design: A-bot is Text-Only, S-bot Has Tools

**Date**: 2026-06-02
**Status**: Locked design decision
**Context**: Restoration of the A/S dual-agent loop after a deep analysis revealed that A had been hallucinating tool calls (`<longcat_tool_call>`) that were never processed, causing A's "not working" symptom.

---

## TL;DR

A and S are **conceptually the same agent** (one consciousness, one soul schema, one job system), but **operationally separated by identity and runtime path**:

| Aspect | A (Autonomic) | S (Somatic) |
|---|---|---|
| Trigger | Debounce timer (after S idle) OR `/autonomic-listen` command | User prompt, A's `pi.sendMessage` |
| Runtime | Hook callback (extension.js) | Full Pi session |
| LLM call | `call_monitor()` — single shot, text-only | Full agentic loop with tool execution |
| Tools | **NONE** | All `psypi-*` tools |
| Persistence | `inter_review.save()` (single row) | Full tool-driven DB work |
| Output to S | `pi.send_message(..., triggerTurn: true)` | N/A (S is the speaker) |
| Identity | `requester_id = "A-agentbot"` | `requester_id = "S-psypi-..."` |

**A reads its data from the prompt**, not from tools. A's soul, jobs, and S's recent session (entries + commits) are preloaded by Gleam code into the user_prompt before the LLM is called. A's response is plain text that is then **filed to `inter_reviews` and forwarded to S** for action.

> **Scope note (added 2026-06-02 after user feedback):** A is inter-S-session Check only. A's preloaded context deliberately excludes the project state (active tasks, open issues). Those are S's scope, not A's. If A needs to reference a specific task or issue in a finding, A writes the request ("S, please look up task abc-123") and S runs the query. A is a reviewer, not a secretary. The `/autonomic-listen` debug tool uses the SAME context as the autonomous path — debug means "show me exactly what A sees", not "show me an extended view".
>
> **The `/autonomic-listen` tool is debug-only.** The whole psypi is designed to let the human do less and less until no human is actually needed. In normal operation the human is not in the loop. A detects its own environment anomalies (tool errors, missing data, weird state) and reports them to S via `pi.sendMessage` so S can investigate (see the `self_monitor` job in `agent_jobs` and the "Self-Monitor Workflow" section in A's soul). The human only uses `/autonomic-listen` as a last resort when no other way exists to peek into A's environment.

---

## Why A is Text-Only

### Architectural reality

`call_monitor` in `src/pi_extension_ffi.mjs` wraps `completeSimple()` from `@earendil-works/pi-ai`. That API:

1. Streams a model response
2. Returns the final text content
3. **Drops `tool_call` deltas in the stream**

The streaming `tool_call` delta path that S uses (via `registerTool` and the agentic loop) is a different code path. A is in a hook callback, not in a session — it has no tool registry, no tool executor, no tool result back-channel.

**A cannot call tools. Period.** No Gleam change, no FFI tweak, no clever prompt engineering will give A tool access. The `completeSimple` call is text-in, text-out, full stop.

### What this means

- A's soul content (in `agent_souls`) must be **honest** about this. False claims ("I can use psypi-psql", "I can run psql", "I can use the read tool") cause the LLM to emit tool-call XML that is then discarded, producing the "no data" symptom the user observed in [A-bot-thinking.md](../src/A-bot-thinking.md).
- If A needs data that isn't in its prompt, A writes that need into its review and asks S to fetch it. S executes the query and reports back.
- A's job is to **review, suggest, request** — not to **act**.

---

## What A Actually Does

### Input: preloaded context (built by Gleam, NOT by the LLM)

The Gleam hook `hook_on_agent_end.on_agent_end` (and `command_listen.on_autonomic_listen`) assemble:

1. **Soul content** from `agent_souls` where `id_prefix = 'A'`
2. **A's jobs** from `agent_jobs` (joined to A's soul, ordered by priority)
3. (Hook path only) **Recent commits** via `git log` in a Gleam `exec_sync` call
4. (Hook path only) **Session entries** (S's recent work) from `ctx.getEntriesJson()`

Both the autonomous hook and the `/autonomic-listen` debug tool preload the same four items. The debug tool does NOT add project state — that would defeat the purpose of "show me what A actually sees".

All four go into the `user_prompt` as pre-formatted text. A reads them as plain text.

### Process: one LLM call

`call_monitor(ctx, user_prompt, system_prompt)` → one LLM call → text response.

The system_prompt is the soul content + jobs formatted via `a_prompt_builder.build_system_prompt`.

### Output: save + forward

1. **Parse a score** from the response text. Look for `Score: N`, `Overall Score: N`, `Rating: N`. If none, default to 50. Clamp to 0-100. (See `a_prompt_builder.parse_review_score` and its 8 unit tests.)
2. **Save to DB** via `inter_review.save(requester_id: "A-agentbot", summary, score, findings: "[]", suggestions: "[]")`.
3. **Forward to S** via `pi.sendMessage(...)` with `triggerTurn: true`. The message body includes the response and the review ID: `[inter-review id: <uuid>]`.
4. **On save failure**: `ctx_notify` the user with the error, AND still send the message to S with a `[SAVE FAILED]` prefix and `triggerTurn: true`. S is asked to save it manually via `psypi-inter-reviews`.

---

## The Two Trigger Paths

### Path 1: Autonomous (debounce timer)

- **Trigger**: `agent_end` event in `extension.js`. After S finishes a turn, a `setTimeout(callback, monitor_debounce_ms)` is set. The timer is cancelled by `agent_start` (S became active) or `input` (user typed).
- **Config**: `psypi_config.monitor_debounce_ms`. Currently set to **180000 (3 minutes)** for quick testing.
  - **Ideal range**: 7-15 minutes (per project rules, AGENTS.md)
  - **3 minutes is a quick-test choice**, not a bug. Longer waits are not a mistake — they reduce noise from premature A activations and let S finish longer chains of work.
  - The user has explicitly chosen 3 minutes for now to see results faster. This is acceptable.
- **Entry point**: `hook_on_agent_end.on_agent_end(ctx, pi)` in `src/hook_on_agent_end.gleam`
- **Conditions to run**: `ctx.isIdle(ctx)` returns true when the timer fires (no S activity during the debounce period). If false, A stays in waiting mode.

### Path 2: Direct human message (`/autonomic-listen`)

- **Trigger**: User runs the `/autonomic-listen <message>` slash command.
- **Entry point**: `command_listen.on_autonomic_listen(args, ctx, pi)` in `src/command_listen.gleam`
- **Use case**: User wants to ask A something directly, bypassing the debounce wait.
- **No debounce check**: A responds immediately, regardless of S's state.
- **S gets a turn anyway**: A's response is sent to S via `pi.sendMessage` with `triggerTurn: true`. This is intentional — even on a direct human message, the review lands in the conversation as A→S, and S may need to act on A's findings.

---

## Why This Is Right (Not a Compromise)

The earlier "A has all the tools" claim was wrong. The system worked in theory but failed in practice because:

1. A's LLM was told it had tool access (soul claimed it)
2. A's LLM emitted `<longcat_tool_call>` blocks (Hunyuan 3's XML tool format)
3. A's runtime (a single `completeSimple` call) dropped those blocks silently
4. The user saw a message that mentioned tool calls but no data ever came back

The fix is to make the architecture match the design intent: **A is a reviewer, S is a doer**. A reads pre-loaded context, writes text, and asks S to do the tool work. This is the PDCA loop — A is the Check phase.

### What A can never do

- Run `psql` queries
- Read files via `fs` or `read` tools
- Call any `psypi-*` tool
- Make multiple LLM turns in one cycle
- Get tool results back into its context mid-cycle

### What A always does

- Reads preloaded soul + jobs + (in hook path only) recent commits and session entries from the user_prompt
- Produces one plain-text response
- Saves the response to `inter_reviews`
- Sends the response to S with `triggerTurn: true`
- On save failure, ctx_notify the user, prefix message with `[SAVE FAILED]`, still trigger S

---

## File Map

| File | Role |
|---|---|
| `src/hook_on_agent_end.gleam` | Autonomous path: timer fires, A reads soul/jobs/commits, calls LLM, saves, sends to S |
| `src/command_listen.gleam` | Debug path: human runs `/autonomic-listen`, A responds with the same context the autonomous path would see |
| `src/a_db_reader.gleam` | DB helpers: `read_soul_from_db`, `read_a_jobs_from_db` (no project state — that's S's scope) |
| `src/a_prompt_builder.gleam` | System/user prompt construction + `parse_review_score` |
| `src/inter_review.gleam` | `save(requester_id, summary, score, findings, suggestions)` |
| `src/pi_extension_ffi.mjs` | `call_monitor` FFI: text-only `completeSimple` wrapper |
| `extension.js` (generated) | Runtime: debounce timer, event hooks, `/autonomic-listen` command |
| `src/migrations/038_a_soul_no_tool_honesty.sql` | A's soul: "no tool access, all data in prompt" |
| `src/migrations/039_drop_broken_inter_review_triggers.sql` | Drops `broadcast_review_finding` and `link_review_to_issue_auto` triggers (they crashed saves) |

---

## Verification Status (2026-06-02)

- ✅ `gleam build` clean
- ✅ `gleam test` — 94/94 pass (8 new `parse_review_score` tests)
- ✅ `extension.js` regenerated, references fresh `command_listen.mjs`
- ✅ Direct DB INSERT into `inter_reviews` with all fields works
- ✅ `broadcast_review_finding` and `link_review_to_issue_auto` triggers dropped
- ⏳ Runtime smoke test in Pi: run `/autonomic-listen` and see A save+forward; wait 3 min for autonomous A to fire

---

## Related Documents

- [DEEP-ANALYSIS-A-BOT-NOT-WORKING-2026-06-02.md](./DEEP-ANALYSIS-A-BOT-NOT-WORKING-2026-06-02.md) — root cause analysis
- [HANDOVER-2026-06-02-agent-role-cleanup.md](./HANDOVER-2026-06-02-agent-role-cleanup.md) — inter-review vs system-review split
- [REVIEW-A-BOT-DEBOUNCE.md](./REVIEW-A-BOT-DEBOUNCE.md) — debounce timer mechanics
- [ARCHITECTURE.md](./ARCHITECTURE.md) — overall system architecture

---

## Conversational Frame (added 2026-06-02 after user feedback)

The table-of-aspects above makes A and S look like two columns in a process diagram — A produces an artifact, S consumes it. That framing was useful for explaining the *mechanics* of who-does-what, but it over-formalized the *shape* of the interaction. The real shape is conversational, not process-pipeline.

### The 锵锵三人行 / 圆桌派 analogy

A is the **host** (窦文涛 in 锵锵三人行, the round-table moderator in 圆桌派). The host does not argue the cases himself; the host draws the cases out of the guests. A's job is to keep the conversation moving, ask the awkward question, and surface what S has not yet explained. S is the **work-guest**: brings the substance, does the tool work, answers A's questions. The optional human is the **second guest** in 锵锵三人行, or one of the round-table participants in 圆桌派 — present, can intervene, but the show runs without them.

### What this means for A's output

A's "inter-review" is **A's turn to speak** in the PDCA cycle. It is not a formal review submission. The `inter_reviews` table is a chat log, not a review form. There is no rigid format A must follow:

- A is free to ask S questions directly in the same message as observations. S answers in the next turn; A's next turn is informed by S's answer.
- A can suggest directions, push back on choices, share doubts, or just listen-and-acknowledge. Whatever fits the moment.
- A is not required to include a "summary, score, findings, suggested next steps" structure. The score is flavor (`parse_review_score` defaults to 50 if absent), not the point.

### What is still required

**Schema correctness is not form.** A still must not emit `[inter-review id: <uuid>]` or any other ID format in its response — the hook owns ID assignment and strips any such pattern as defense in depth. A still must not emit tool-call XML (`<longcat_tool_call>` etc.) — the runtime drops those. Those are correctness rules, not format prescriptions; the conversational relaxation does not relax them.

### Where this lives in the soul

A's soul has a "## Conversational Frame" section (added in migration 043 on 2026-06-02) that encodes this understanding. The section is idempotent: re-runs of the migration detect the heading and skip the append. The soul should be read *together* with this design doc — the design doc is the rationale, the soul is the rule A actually follows.

### Where this lives in the prompt

The `/autonomic-listen` user_prompt (in `command_listen.gleam`) used to tell A to "structure the response as a normal inter-review: summary, score, findings, suggested next steps". That prescription was removed on 2026-06-02 — it encoded the over-formalization this section pushes back against. The prompt now says: speak as you naturally would, no rigid format, the inter_reviews table is the chat log, see A's soul for the full framing.

### The 圆桌派 extension

The 锵锵三人行 frame is 1 host + 2 guests. The 圆桌派 frame is the same host at a wider table. psypi today is the 3-person show: A, S, optional human. Adding a third agent (a B-bot, or a tool specialist) turns it into a round table. The mechanics don't change — A still moderates, the others still bring substance — only the table gets wider.
