---
description: Agent instructions for psypi (READ FIRST!)
---

# AGENTS.md - PsyPI Quick Guide

## 🚨 FIRST: Read docs/DREAM-TEAM-ARCHITECTURE.md

The dream-team architecture is the core concept. One AI, two SOULs, alternating current.

**Key principle:** Hooks are THIN. Intelligence is in the LLM. Small modules (< 100 lines).

## 🎯 Project Overview

**psypi** = **Psyche + Pi** = AI coordination system with Self-Improving Architecture
- **Technically**: psypi is a **Pi TUI with a Gleam-generated extension**! 🔄
- **Architecture**: Gleam core + Pi runtime + Dual Identity System (Worker/Monitor)
- **Database**: ONE PostgreSQL per user home (shared across ALL projects)
- **Status**: ✅ Working - Autonomic Worker directs Somatic Worker via direct messaging
  - ✅ A-worker uses `ctx.isIdle()` checks (NOT lifecycle hooks!)
  - ✅ A-worker waits 3 seconds, checks again if still idle
  - ✅ If idle, A-worker sends visible messages to S-worker
  - ✅ No more database injection or `before_agent_start` hook nonsense
  - ✅ Direct messaging: `pi.sendMessage()` with `[Monitor]` prefix

## 🚨 CRITICAL RULES (Read FIRST!)

**All Pi tools are intended to be used *inside* the running Psypi TUI.

**Note:** In psypi, the AIs themselves run inside the continuously running Pi TUI, not as separate processes.

**Therefore, they can invoke Pi tools directly from the TUI** (e.g., `/psypi‑my-id`, `/psypi‑commit`, etc.)**

- You never invoke them as ordinary shell commands (e.g. `psypi‑task‑add`).
- The Pi runtime provides a built‑in tool‑call interface; just type the tool name prefixed with a slash (`/psypi‑task‑add …`) in the TUI prompt.
- The underlying JSON wrapper exists only for internal communication; it is not a user‑visible API.
- Trying to run a Pi tool from the OS will result in “command not found”.
- This guarantees that the Monitor, Hooks, and Worker all share the same runtime context and state.

Below you will find quick usage examples and a reference for the most common tools.

### 0a. GLEAM TYPE SYSTEM: Use It Properly!

**This codebase was ported from TypeScript. A common mistake: Gleam types exist but are bypassed at the boundaries.**

**Rule: Enums are the source of truth. Validate at the boundary, use internally, convert at the DB edge.**

**Correct pattern for any user-facing input:**
```
User input (String) → string_to_*() → Result(Enum, Error)
  → Error: reject with clear error message
  → Ok(enum_val): use enum throughout Gleam code → enum_to_string() → DB write
```

**Anti-pattern (NEVER do this):**
```
User input (String) → string_to_*() → Enum (silently defaults unknown values)
  → bypass enum, pass raw string directly to DB
  → DB check constraint catches it (if you're lucky)
```

**Concrete example from `src/issue.gleam` (fixed 2026-05-15):**
- OLD: `string_to_type("task")` → silently returned `Bug` → DB constraint violation
- NEW: `string_to_type("task")` → returns `Error("Invalid issue_type: task. Allowed: bug, inconsistency, feature, improvement, question, debt")`

**When adding/modifying Gleam code:**
1. Define the enum/type properly
2. Write `string_to_*` converters that return `Result`, NOT silent defaults
3. Write `*_to_string` converters for DB writes
4. Use the enum variant in all Gleam logic (pattern matching, function args)
5. Only convert to String at the DB boundary

**NEVER pass raw user strings directly to SQL. ALWAYS validate through the enum first.

### 0. THE BIG PICTURE: 100% Gleam + Pi Tools!
**psypi is a Pi TUI with a Gleam-generated extension:**
- **OLD way**: `psypi my-id` (CLI command → TypeScript → DB)
- **NOW**: `psypi` (spawns Pi TUI) → Pi tools → Gleam → DB

**Strategy:**
1. **Pi tools ONLY** - All functionality via Pi tools (psypi-my-id, psypi-tasks, etc.)
2. **NO CLI commands** - TypeScript fully removed, all TS files in `deprecated/` directory
3. **psypi = Pi TUI entry point** - `bin/psypi.mjs` generates extension.js from Gleam, then spawns Pi
4. **NEVER spawn Pi from Pi tools** - infinite loop danger!

**Current Status:**
- ✅ 29+ Pi tools working
- ✅ System prompt injection: Monitor → DB notifications → Worker
- ✅ 30 event hooks mapped (7 active) in `psypi_event_hooks` table
- ✅ Single node_ffi.mjs (consolidated from 4)
- ✅ All TypeScript removed — 100% Gleam core
- ✅ `bin/psypi.mjs` auto-generates `extension.js` at every startup
- ✅ ID computed from function call (no cache), SOUL in `souls` table

---

## 🚨 CRITICAL WARNING: NEVER SPAWN PI FROM PI TOOLS!

**INFINITE LOOP DANGER! SYSTEM CRASH IN MINUTES!**

If a Pi tool tries to spawn another Pi process:
```
Pi Tool → spawn('pi') → New Pi → Pi Tool → spawn('pi') → New Pi → ...
```
**Result: System resources exhausted in minutes, crash guaranteed!**

**Why this is fatal:**
- Each Pi spawns another Pi → exponential growth
- CPU, memory, disk handles run out
- System becomes unresponsive
- Only hard reboot recovers (Ctrl+C doesn't work!)

**Dangerous patterns (NEVER use in Pi tools or extension.js):**
```javascript
// ❌ NEVER DO THIS IN PI TOOLS!
import { spawn } from 'child_process';
spawn('pi', ['-e', 'extension.js']);  // INFINITE LOOP!

// ❌ ALSO NEVER!
spawn('psypi', ['autonomous']);  // Same infinite loop!

// ❌ NOT EVEN THIS!
exec('pi -e extension.js');  // Still spawns Pi!
```

**Safe spawn points (entry points ONLY - NEVER in Pi tools):**
- ✅ `bin/psypi.mjs` - Entry point, spawns Pi with extension
- ✅ `gleam/.../main_ffi.mjs` - Entry point from `main.gleam`

**Rule: Pi tools should call Gleam functions directly, NOT spawn Pi!**

### 1. ID + SOUL: Two Identities, Two SOULs

Each identity must maintain itself:

- **ID** — Computed from function call (`generate_semantic_id()`). Pure function, no cache, no DB. Format: `(A|S)-source-project-model[-thinking_level]`. Model and thinking level come from `ctx.model` (live reference, always current). See `docs/AGENT-IDENTITY.md` for full details.
  - Worker: `S-psypi-psypi-openrouter/owl-alpha` → name="Worker", traits
  - Monitor: `A-psypi-psypi-openrouter/owl-alpha` → name="Monitor", traits
  - With thinking: `A-psypi-psypi-anthropic/claude-opus-4-5-high`
- **SOUL** — Stored in `souls` table. Each identity owns its entry.

Both can modify their SOUL via meetings or direct DB. Monitor acts as senior advisor — detects identity drift and redirects Worker.

#### `ctx.model` — Live Model Reference

The Pi SDK provides `ctx.model` on every event handler and tool `execute()` call.
It is a **live getter** — always reflects the current model even if changed mid-session:

```javascript
// In generated extension.js tool wrappers:
async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
    const modelId = ctx.model?.id || '';              // "openrouter/owl-alpha"
    const thinking = ctx.model?.thinkingLevel || '';  // "medium" or ""
    const provider = ctx.model?.provider;              // "openrouter"
    const ctxWindow = ctx.model?.contextWindow;        // 128000
}
```

**Key facts:**
- `ctx.model` is live — reads `AgentSession.model` at call time
- `pi.setModel()` changes the model; `ctx.model` reflects it immediately
- `settings.json` is NOT updated on `/model` change — use `ctx.model` for truth
- `ctx.model.thinkingLevel` is the active thinking level ("off"|"minimal"|"low"|"medium"|"high"|"xhigh")
- There is NO `pi.getModel()` — use `ctx.model` instead
- See `docs/AGENT-IDENTITY.md` for the full identity system documentation

### 2. DELETE (don't deprecate!) - Move obsolete files to `deprecated/` directory!
**CORRECT approach:**
```bash
# ✅ CORRECT - Move to deprecated/ directory
mv file.ts deprecated/

# ❌ WRONG - Don't leave .ts.deprecated files around!
mv file.ts file.ts.deprecated
```

**Why?** All TS files are backed up in the code_versions database. The `deprecated/` directory keeps them for reference without cluttering the source tree.

---

### 3. FORCE YOURSELF: Use `psypi-commit` Pi tool (NOT `git commit`!)
Inside Pi TUI, run:
```
psypi-commit "feat: My change"
```
This uses Gleam review (Monitor AI).

Outside Pi, use:
```
git commit -m "feat: My change"
```
(But bypasses review - only for when Pi tool unavailable!)

---

### 4. ONE SINGLE WAY: Agent ID
Use the `psypi-somatic-id` and `psypi-autonomic-id` Pi tools. For Gleam code, use the `agent_identity.gleam` module.

### 4a. DIRECTIVE SYSTEM (Autonomic → Somatic Communication)
- **`psypi-direct-worker`**: ONLY the Autonomic Worker (A-) uses this to set directives for the Somatic Worker
- **`psypi-clear-directives`**: Clear active directives
- Directives are injected into the Somatic Worker's system prompt via `before_agent_start` hook
- Directives include SOUL context so workers know who's directing them
- Directives are consumed after injection (one-time use) and expire after 1 hour
- **Somatic Worker should NEVER call `psypi-direct-worker`** — it will return ERROR

---

### 5. READ FILES FIRST before editing!
- ✅ `read` file first, then `edit` with EXACT match
- ❌ Never use `sed` on files > 5 lines (corrupts them!)

---

### 6. Database First - Use psypi tools, NOT psql!
```bash
psypi tasks          # ✅ Correct
psql -c "SELECT..." # ❌ Wrong - bypasses psypi code!
```

---

### 7. Package Manager: pnpm (NOT npm!)
```bash
pnpm install   # ✅ Correct
npm install    # ❌ Wrong
```

---

## 📊 Current Status (2026-05-13)

### 🎯 Architecture Evolution
**OLD**: CLI commands → TypeScript → Database
**NEW**: Pi TUI → Pi tools → Gleam → Database

### The Cycle: Monitor Directs Worker

```
USER → Worker → Monitor → Worker → (USER) → Cycling on
```

Monitor writes to DB → `before_agent_start` hook reads DB → injects into system prompt → Worker continues.

### Pi Tools Status:
- **29+ Pi tools** working ✅:
  - Identity: `psypi-my-id`, `psypi-autonomic-id`
  - Tasks: `psypi-task-add`, `psypi-tasks`, `psypi-task-complete`
  - Stats: `psypi-stats-show`
  - Code: `psypi-doc-save`, `psypi-doc-list`
  - Issues: `psypi-issue-add`, `psypi-issues`, `psypi-issue-resolve`
  - Skills: `psypi-skill-list`, `psypi-skill-get`, `psypi-skill-search`
  - Meetings: `psypi-meetings`, `psypi-meeting-get`, `psypi-meeting-opinions`
  - Memory: `psypi-learn-save`, `psypi-memory-search`
  - Broadcast: `psypi-broadcast-send`, `psypi-broadcasts`
  - Reflection: `psypi-areflect`
  - Agents: `psypi-agents`
  - Event hooks: `psypi-hooks-list`, `psypi-hooks-active`
  - Monitor: `psypi-autonomic-status`, `psypi-autonomic-health`, `psypi-autonomic-alerts`, `psypi-autonomic-stats`, `psypi-autonomic-suggest`, `psypi-autonomic-consult`, `psypi-commit`

### Active Event Hooks:
| Hook | Action |
|------|--------|
| `session_start` | Health check, record model |
| `before_agent_start` | Read DB notifications → inject into system prompt |
| `tool_call` | Safety check, activity log, auto-backup |
| `tool_result` | Detect errors → create notification + auto-file issue |
| `model_select` | Record model changes |

### Build:
- ✅ `rm -rf build/ && gleam build` (ALWAYS clean build first!)
- ✅ `gleam run -m simple_migrate` (run DB migrations first!)
- ✅ `gleam run -m extension_generator` (regenerate extension.js!)
- ❌ `pnpm build` DOES NOT EXIST! (no `tsconfig.json`, no `package.json`!)

**🚨 ALWAYS `rm -rf build/` before `gleam build`** — stale compiled output causes subtle bugs!

### 🚨 CRITICAL Architecture Rule:
**Pi Extension = Generated from Gleam PiToolCall types!**
- `extension.js` is AUTO-GENERATED at every `psypi` startup from Gleam `PiToolCall` values
- **NEVER hand-edit `extension.js`** — it's a build artifact, always regenerated
- Each Gleam module exports `PiToolCall` values that define Pi tools
- The generator collects `PiToolCall` values → composes JS text → writes `extension.js`
- **Skill**: `gleam-pi-tool-generator` has the complete guide

**Correct Pattern:**
- `bin/psypi.mjs` → imports compiled Gleam generator → generates `extension.js` → spawns Pi ✅
- `extension.js` → auto-generated from `PiToolCall` values ✅
- Hand-editing `extension.js` → ❌ NEVER! Always goes through Gleam types!

**Files:**
- `src/pi_tool_call.gleam` — PiToolCall type + text converters
- `src/extension_generator.gleam` — text composer (the cook)
- `extension.js` — generated output (do not edit!)

**To add a new Pi tool:**
1. Define the Gleam function in its module
2. Create a `PiToolCall` value (e.g., `my_tool()`)
3. Import it in `extension_generator.gleam` and add to `all_tools()`
4. Build: `rm -rf build/ && gleam build`
5. Generate: `gleam run -m extension_generator`
6. Verify `extension.js` has the new tool

### ⚠️ CRITICAL WARNING:
**NEVER run `psypi autonomous` from CLI!**
- It launches Pi TUI interactively
- If Pi runs `psypi autonomous` tool, it calls ANOTHER Pi → INFINITE LOOP!
- This eats all system resources in minutes!
- **FIXED**: `psypi-autonomous` is now a Pi-only tool (not a CLI command)

### 🚨 CRITICAL: Build Cache Issue
After editing Gleam source, `gleam run` sometimes uses stale compiled output from `build/`. **Always clean:**
```bash
rm -rf build/ && gleam build
```

---

## 🎯 Your Partner (Monitor/Autonomous AI)
- **ID**: `A-psypi-psypi`
- **Job**: Reviews commits via Gleam `run_review()`, monitors system health, sends notifications to Worker
- **Tools**: `psypi-autonomic-status`, `psypi-autonomic-health`, `psypi-autonomic-alerts`, `psypi-autonomic-stats`, `psypi-autonomic-suggest`, `psypi-autonomic-consult`, `psypi-commit`

### Event Hooks for Autonomous AI
Autonomous AI integrates via Pi event hooks in `extension.js`:
- `session_start` — Session initialization, health check
- `before_agent_start` — System prompt injection (notifications)
- `agent_start` — Agent lifecycle start
- `agent_end` — Agent lifecycle end
- `tool_call` — Safety checks, auto-backup, activity logging
- `tool_result` — Error detection, auto-create notifications

### Monitor Skill
Worker can consult Autonomous AI via the `monitor` skill (`.pi/skills/monitor/SKILL.md`):
- **When**: architectural decisions, safety concerns, trade-offs, quality checks
- **How**: Use `psypi-autonomic-consult` tool or ask "Should I ask Monitor about...?"

---

## 📚 Key Files (Read These!)
- `docs/cli-vs-pi-tools.md` - Complete CLI ↔ Pi tool mapping
- `AGENTS.md.deprecated` - Old version (for reference only)
- `docs/MIGRATION-TS-TO-GLEAM-2026.md` - Gleam migration plan

---

**Remember**: 
- ✅ Use `psypi-commit` Pi tool (mandatory review!)
- ❌ NEVER run `pnpm build` — it doesn't exist anymore!
- ✅ Delete/move to `deprecated/` — never leave `.ts.deprecated` files around
- ✅ Always `rm -rf build/` before `gleam build`
- ✅ Short + Simple = Better!

---

## 🚨 CRITICAL: `package.json` Does NOT Exist!

**Current State (2026-05-12):** `package.json` has been removed. `tsconfig.json` has been removed.

**What's Required (Must-Have!):**
1. ✅ `gleam.toml` - Gleam project config!
2. ✅ `src/*.gleam` - Gleam source code!
3. ✅ `bin/psypi.mjs` - Entry point (generates extension.js, spawns Pi)
4. ✅ `build/dev/javascript/psypi/` - Compiled Gleam `.mjs` files!
5. ✅ `node_modules/` - Runtime deps (`pg`, `@sinclair/typebox`!)
6. ✅ `pnpm-lock.yaml` - Lock file for restoring `node_modules/`

**What's NOT Required:**
- ❌ Root `package.json` - Does NOT exist!
- ❌ `tsconfig.json` - Does NOT exist! (TypeScript fully removed)
- ❌ `pnpm install` - ONLY if you delete `node_modules/` and need to restore it

**Gleam has OWN package management:**
- `gleam.toml` (NOT `package.json`!) handles Gleam deps!

---

## 🧠 Self-Loading Skills logic
**Don't wait for a skill to be provided in the prompt.**
If a task requires specialized expertise (e.g., Gleam, Planning, Pi Platform), you can "load" the skill yourself:
1. Find the skill file: `ls -R .pi/skills/`
2. Read the `SKILL.md` file: `read path=".pi/skills/[skill-name]/SKILL.md"`
3. Internalize the guidelines and apply them to the current task.

This turns the AI from a passive receiver into an active specialist.

### 📝 Concrete Example: How I Loaded a Skill

See `docs/concrete-single-loading-example.md` for a verbatim record of the moment I transitioned from general AI advice to specialist mode by strictly following the `<input>` -> `<routing>` -> `<execution>` protocol of a loaded skill.

---

## 📢 IMPORTANT UPDATE (2026-05-13)

### Monitor Evolution: System Prompt Injection

Monitor now directs Worker through DB notifications + system prompt injection:

```
tool error → tool_result hook → DB notification
                                    ↓
before_agent_start → reads notifications → injects [MONITOR ALERT] → Worker sees it
```

**Active hooks (2026-05-13):**

| Hook | Status | Action |
|------|--------|--------|
| `session_start` | active | health check, record model |
| `before_agent_start` | active | inject notifications from DB |
| `tool_call` | active | safety check, activity log, auto-backup |
| `tool_result` | active | detect errors → notification + auto-file issue |
| `model_select` | active | record model changes |
| `agent_start/end` | active | silent logging |

**psypi_event_hooks table** — Monitor reads this to know which events to act on. 30 events mapped (7 active). Monitor can modify via `psypi-hooks-list` / `psypi-hooks-active` tools.

**New tools:**
- `psypi-hooks-list` — List all event hooks
- `psypi-hooks-active` — List active hooks only

**Identity:**
- Worker: `S-psypi-psypi-<model_id>[-<thinking_level>]` (prompt-driven)
- Monitor: `A-psypi-psypi-<model_id>[-<thinking_level>]` (event-driven)
- Both maintain own ID (pure function, model-aware via `ctx.model`) and SOUL (DB entry)
- See `docs/AGENT-IDENTITY.md` for full details

**⚠️ NEVER run `psypi` inside opencode** — infinite loop risk, system crash in minutes!

See `.planning/` docs for full architecture: `NEXT-PHASES.md`, `EVENT-TASK-MAPPING.md`, `SYSTEM-PROMPT-INJECTION.md`.



### Tool Call Schema Errors (HTTP 400)
If you encounter `invalid_argument` or `parameters format error` when calling Pi tools:
- **Cause**: The model is wrapping simple parameters in JSON objects (e.g., sending `{"title": {"text": "..."}}` instead of `{"title": "..."}`).
- **Fix**: Ensure parameters exactly match the required type (String, Boolean, Number) and are not wrapped in extra objects.
- **Common in**: Some local models (Ollama) or non-frontier models (Baidu, etc.) that struggle with strict JSON Schema tool-calling.

### Local Model Limitations
When using local models (Ollama) for development:
- **Depth**: Local models may struggle with complex architecture and multi-file dependencies.
- **Solution**: Use local models for simple edits and reads; use frontier models (Claude/GPT) for planning and critical reviews.
- **Recommended Local Models**: `Codestral` (22B), `DeepSeek-Coder-V2-Lite` (16B).
