---
name: psypi-basics
description: Quick cheat‑sheet for using Psypi from the TUI (Autonomic vs Somatic, IDs, common tools, commit workflow). All psypi tools are Pi agent tools — only AIs use them, not human users. Reference resources available at ../refers/pi/.
---

# Psypi Basics (for AI Agents)

> **Important:** All psypi tools are Pi agent tools. They are designed for AI agents, not human users. Humans interact with the system through the Pi TUI chat interface, not by invoking tools directly.

## Core concepts
- **Autonomic Agentbot** (`A‑…`) – autonomous, event‑driven, monitors the system.
- **Somatic Agentbot** (`S‑…`) – prompt‑driven, reacts to user or Monitor‑injected prompts.
- They are the *same AI*; the only difference is the ID prefix (`ctx.isIdle()` at call time).
- The ID is always freshly computed (no cache). Format: `(G-)(A|S)-<project>-<source>-<model>[-<thinking_level>]`
  - Example: `S-psypi-openrouter/owl-alpha` or `A-psypi-openrouter/owl-alpha-high`
  - When no `.git` found in cwd, prepends `G-` (e.g., `G-S-psypi-openrouter/owl-alpha`)
- **Pi Reference Resources** – For advanced Pi patterns, see `../refers/pi/` with prompts like `cl.md` (changelog), `is.md` (issue analysis), `pr.md` (PR review), `wr.md` (work wrapup)

## Getting your identity
```
/psypi-my-id            # returns the calling agent's ID (S- or A- prefix)
```
The prefix is determined by `ctx.isIdle()` at the moment of the call: `S-` when called by the Somatic Agentbot (prompt-driven), `A-` when called by the Autonomic Agentbot (event-driven). There is only one tool — every agent calls the same one and gets the correct identity automatically.

## Common Pi-tools (use **inside the Psypi TUI**; just type a leading `/`)

### Tasks
```
/psypi-task-add title="Write docs"
    → creates a task, returns its UUID. (title required)
/psypi-tasks [status="pending"] [project_id="..."]
    → lists tasks, optionally filtered. (all params optional)
/psypi-task-complete task_id="<uuid>"
    → marks a task as completed.
```

### Issues
```
/psypi-issue-add title="Bug" description="Details" severity="high" issue_type="bug"
    → creates an issue. (all params required)
/psypi-issues [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
    → lists issues with optional filters.
/psypi-issue-count [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
    → counts issues matching filters.
/psypi-issue-get id="<uuid>"
    → gets a single issue by ID.
/psypi-issue-resolve id="<uuid>"
    → resolves an issue by ID.
```

### Reflection (parse markdown markers)
```
/psypi-areflect text="... [LEARN] ... [ISSUE] ... [TASK] ... [ISSUELIST] ..."
    → Parses [LEARN], [ISSUE], [TASK], [ISSUELIST] markers from text and saves to DB.
```

### Commit with Monitor review (QC Two-Phase)
```
/psypi-commit message="Refactor ID handling"
    → Phase 1: stages changes, sends review request to S-worker.
      A reviews diff, responds PASS/FAIL + score + review_id.
/psypi-commit message="Refactor ID handling" review_id="<uuid>"
    → Phase 2: commits with review_id as proof of QC approval.
      The review_id is the "ticket" — no ticket, no commit.
```
**Important:** S MUST use `psypi-commit` for all commits. The two-phase review ensures A reviews S's work before it lands. There is no self-review loop — A is the reviewer, not S.
Proper flow: S makes changes → S calls psypi-commit (no review_id) → A reviews diff → A responds with review_id → S calls psypi-commit with review_id → commit lands.

### Meetings (discussion between Somatic and Autonomic workers)
```
/psypi-meeting-add topic="Discussion topic" created_by="S-..."
    → creates a new meeting, returns meeting ID.
/psypi-meeting-say meeting_id="<id>" message="Your opinion"
    → adds your opinion to a meeting.
/psypi-meeting-opinions meeting_id="<id>"
    → lists all opinions for a meeting.
/psypi-meetings [status="active"]
    → lists meetings, optionally filtered by status.
/psypi-meeting-get id="<id>"
    → gets a single meeting by ID.
```

### Skills
```
/psypi-skill-list [status="installed"]
    → lists skills, optionally filtered by status.
/psypi-skill-get id="<name>"
    → gets a skill by name.
/psypi-skill-search query="gleam"
    → searches skills by name/description.
```

### Learning & Memory
```
/psypi-learn-save content="..." tags="tag1,tag2" importance="5"
    → saves a learning to memory.
/psypi-memory-search query="keyword" limit="10"
    → searches memories by keyword.
```

### Broadcast
```
/psypi-broadcast-send message="Hello" priority="normal" project_id="psypi"
    → sends a broadcast message.
/psypi-broadcasts limit="10"
    → lists recent broadcast messages.
```

### Agents
```
/psypi-agents
    → lists all registered agents from the database.
```

### Monitor / Autonomic status
```
/psypi-autonomic-status
    → returns Monitor status and capabilities.
/psypi-autonomic-health
    → returns system health metrics (failed tasks, open issues, activity).
/psypi-autonomic-alerts
    → returns active alerts (failed tasks, open issues).
/psypi-autonomic-stats
    → returns Monitor statistics (review scores, response times, failure rate).
/psypi-autonomic-suggest
    → returns work suggestions (open issues, stale tasks, pending skills).
```

### Event hooks
```
/psypi-hooks-list
    → lists all psypi event hooks and their status.
/psypi-hooks-active
    → lists only active psypi event hooks.
```

### Directives (REMOVED — use sendMessage instead)
~~`/psypi-direct-agentbot` and `/psypi-clear-directives`~~ have been removed.
A communicates with S via `sendMessage()` — S is an LLM that reads and understands natural language directly. No database intermediary needed.

### Consult (Somatic asks Autonomic for advice)
```
/psypi-consult-autonomic question="Should I refactor this module?"
    → Somatic asks Autonomic for advice on a difficult decision.
```

### Code versioning
```
/psypi-doc-save file_path="src/main.gleam"
    → saves a file version to code_versions table (auto-backup before edits).
/psypi-doc-list file_path="src/main.gleam" limit="10"
    → lists version history for a file.
```

### Stats
```
/psypi-stats-show
    → shows project statistics (tasks, issues, skills, meetings counts).
```

## Slash commands (human-facing, for Monitor interaction)
These are registered as Pi commands, not Pi tools:
```
/autonomic-listen <message>
    → Human talks to Monitor AI directly in chat.
/autonomic-reload
    → Reloads Pi extensions (used after Monitor modifies its own Gleam code).
```

## Important usage notes
- **Never run Pi tools as shell commands** (e.g. `psypi-task-add`). They exist only inside the Pi runtime (`extension.js`). Attempting to call them from the OS will result in "command not found".
- Always invoke them from the **Psypi TUI** prompt.
- **Never cache the ID.** It must be computed fresh every time because `ctx.isIdle()` is live.

## Architecture Overview

```
Gleam source (src/*.gleam)
  ↓ gleam build
Compiled JS (build/dev/javascript/psypi/*.mjs)
  ↓ extension_generator.gleam composes text
extension.js (auto-generated, never hand-edit)
  ↓ Pi TUI loads it
Pi runtime (tools, hooks, commands)
```

### Key architectural rules:
1. **`extension.js` is ALWAYS auto-generated** — never hand-edit it
2. **Gleam `PiToolCall` values define all Pi tools** — add new tools by creating Gleam values
3. **FFI is minimal** — use pure Gleam libraries (simplifile, gleam_json) when possible
4. **Small modules** — each Gleam module should be focused (< 200 lines ideally)
5. **Type safety** — use custom types extensively, `string_to_*()` converters for DB enums
6. **FFI files** (`pi_extension_ffi.mjs`, `node_ffi.mjs`) must use `new Ok(value)` / `new Error(error)` — never plain JS objects

## ⚠️ GOLDEN RULE: No Hand-Written JS in Gleam Code

**99% of all bugs in this codebase were caused by hand-written JS strings embedded in Gleam modules.** This is the #1 thing to avoid.

### The Rule

**NEVER write JavaScript code as Gleam string literals in non-generator modules.** If you need JS interop, use one of these patterns:

1. **Gleam FFI (`@external`)**: For calling Node.js APIs (filesystem, dates, etc.)
   - Create `src/<module>_ffi.mjs` with `export function`
   - Declare in Gleam: `@external(javascript, "./<module>_ffi.mjs", "fn_name")`
   - Example: `time_utils_ffi.mjs`, `agent_identity_ffi.mjs`

2. **Gleam generator functions**: For emitting JS text into extension.js
   - Write Gleam functions that return JS text strings
   - Compose them in `pi_tool_gen.gleam`, `pi_hook_gen.gleam`, `pi_command_gen.gleam`
   - Example: `hook_import_line()`, `success_action_to_js()`, `params_to_js()`

3. **Pi type constructors**: For building tool/hook/command definitions
   - Use `lit()`, `from_param()`, `event_hook()`, `raw_event_hook()`, `template()`
   - Never hand-write JS object literals or IIFEs

### Bug Patterns to Avoid

| ❌ Bug Pattern | ✅ Correct Approach |
|---|---|
| `promise.resolve("new Date().toISOString()")` — returns literal string | FFI function in `*_ffi.mjs` |
| `"(function(){ var cwd = ...; require('fs')... })()"` — JS IIFE | Gleam FFI + Gleam string ops |
| `"(() => { const t = ...; JSON.parse(t); ... })()"` — JS IIFE | Pure Gleam string functions |
| `custom_js("...${r.value}...")` — raw JS in result | `template("...${r.value}...")` |
| Hand-editing `extension.js` | Edit Gleam source, regenerate |

The ONLY hand-written JS file in the repo is `bin/psypi.mjs`. Everything else is auto-generated or uses proper FFI.

## Gleam Code Quality Standards

When working with the Gleam codebase, follow these patterns:

### DO:
- Use `case` expressions for all control flow (no `if/else` in Gleam)
- Use `|>` pipe operator for chaining
- Use `list.map`, `list.filter`, `list.fold` instead of recursion when possible
- Use `@external(javascript, "./ffi.mjs", "functionName")` for FFI
- Use `simplifile` for file operations (pure Gleam)
- Use `gleam_json` for JSON encoding/decoding
- Keep modules small and focused
- Use custom types for all domain concepts
- Make invalid states unrepresentable

### DON'T:
- Don't use hand-written JS in `extension.js` — it's auto-generated
- Don't use `node_pg` FFI when pure Gleam alternatives exist
- Don't create large modules (> 300 lines)
- Don't use plain JS objects `{ ok: true, value: x }` in FFI — use `new Ok(value)` / `new Error(error)`
- Don't cache the agent ID
- Don't use `io.debug` or `string.inspect` (not available in Gleam)

## Pi Prompt Patterns (from refer resources)
Reference Pi prompts available at `../refers/pi/.pi/prompts/`:
- **`cl.md`** – Audit changelog entries before release
- **`is.md`** – Analyze GitHub issues (bugs or feature requests)
- **`pr.md`** – Review PRs from URLs with structured issue and code analysis
- **`wr.md`** – Finish the current task end-to-end with changelog, commit, and push

These can be used by both Autonomic and Somatic agents for standard Pi workflows.

## A-Bot (Autonomic) Status

The A-bot runs as event hooks inside the Pi TUI. Key things to know:
- **agent_end hook**: Fires when S-bot finishes a turn. Starts debounce timer (default 3 min). After debounce, `hook_on_agent_end.gleam` checks idle state and composes wake-up message
- **No early exit before debounce**: The generated JS does NOT check `ctx.isIdle()` before starting the timer. All idle checking happens in Gleam after the debounce period
- **call_monitor**: The FFI function that calls the LLM. Uses `completeSimple` from `@earendil-works/pi-ai`
- **Wake-up messages**: Sent via `pi_send_message` with custom type `autonomic-wakeup`. Appear as `[A-agentbot]` prefix in session
- **Debugging**: If A-bot seems inactive, check: (1) `psypi_config` table has `monitor_debounce_ms`, (2) `ctx.model` is available, (3) API key is valid, (4) hook modules exist in build output
- **Stats all zeros**: `psypi-autonomic-stats` shows zeros because inter_review system hasn't been used yet

## Quick tip
- After any change, run `/psypi-commit` to let the Monitor review and approve the commit. This keeps the single-dreamer cycle safe and autonomous.
- After Gleam source changes: `gleam clean && gleam build` then restart Pi.
- **Restart Pi**: `pkill -f pi-coding-agent; cd /Users/jk/gits/hub/tools_ai/psypi && npx -y @earendil-works/pi-coding-agent --prompt "what is your id?"`
