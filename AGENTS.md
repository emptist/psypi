---
description: Agent instructions for psypi (READ FIRST!)
---

# AGENTS.md - PsyPI Quick Guide

## 🎯 Project Overview

**psypi** = **Psyche + Pi** = AI coordination system
- **Technically**: psypi is a **Pi TUI with extensions**! 🎯
- **Architecture**: Gleam core + Pi runtime (TypeScript fully removed!)
- **Database**: ONE PostgreSQL per user home (shared across ALL projects)
- **Status**: ✅ Working - Gleam reviews via `psypi-commit` Pi tool (inside Pi TUI)!

## 🚨 CRITICAL RULES (Read FIRST!)

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
- ✅ 17 Pi tools working (psypi-my-id, psypi-tasks, etc.)
- ✅ All TypeScript removed — 100% Gleam core
- ✅ `bin/psypi.mjs` auto-generates `extension.js` at every startup

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

### 1. DELETE (don't deprecate!) - Move obsolete files to `deprecated/` directory!
**CORRECT approach:**
```bash
# ✅ CORRECT - Move to deprecated/ directory
mv file.ts deprecated/

# ❌ WRONG - Don't leave .ts.deprecated files around!
mv file.ts file.ts.deprecated
```

**Why?** All TS files are backed up in the code_versions database. The `deprecated/` directory keeps them for reference without cluttering the source tree.

---

### 2. FORCE YOURSELF: Use `psypi-commit` Pi tool (NOT `git commit`!)
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

### 3. ONE SINGLE WAY: Agent ID
Use the `psypi-my-id` and `psypi-partner-id` Pi tools. For Gleam code, use the `agent_identity.gleam` module.

---

### 4. READ FILES FIRST before editing!
- ✅ `read` file first, then `edit` with EXACT match
- ❌ Never use `sed` on files > 5 lines (corrupts them!)

---

### 5. Database First - Use psypi tools, NOT psql!
```bash
psypi tasks          # ✅ Correct
psql -c "SELECT..." # ❌ Wrong - bypasses psypi code!
```

---

### 6. Package Manager: pnpm (NOT npm!)
```bash
pnpm install   # ✅ Correct
npm install    # ❌ Wrong
```

---

## 📊 Current Status (2026-05-10)

### 🎯 Architecture Evolution (BIG CHANGE!)
**OLD**: CLI commands → TypeScript → Database
**NEW**: Pi TUI → Pi tools → Gleam → Database

### Pi Tools Status:
- **18 Pi tools** working ✅:
  - `psypi-my-id` — Get agent ID
  - `psypi-monitor-id` — Get monitor/partner ID
  - `psypi-monitor-consult` — Consult Monitor for difficult decisions
  - `psypi-task-add` — Add a task
  - `psypi-tasks` — List tasks
  - `psypi-stats-show` — Show project statistics
  - `psypi-doc-save` — Save file version to code_versions DB
  - `psypi-issue-add` — Add a new issue
  - `psypi-issues` — List issues
  - `psypi-issue-resolve` — Resolve an issue by ID
  - `psypi-skill-list` — List skills
  - `psypi-skill-get` — Get a skill by ID
  - `psypi-skill-search` — Search skills by name
  - `psypi-meetings` — List meetings
  - `psypi-meeting-get` — Get a meeting by ID
  - `psypi-meeting-opinions` — List opinions for a meeting
  - `psypi-learn-save` — Save a learning to memory
  - `psypi-memory-search` — Search memories by keyword
- **TypeScript** fully removed — all files in `deprecated/` directory
- **psypi** = Pi TUI entry point (generates extension.js from Gleam, then spawns Pi)

### Build:
- ✅ `cd gleam/psypi_core && rm -rf build/ && gleam build` (ALWAYS clean build first!)
- ❌ `pnpm build` DOES NOT EXIST! (no `tsconfig.json`, no `package.json`!)
- ✅ Gleam review via `psypi-commit` Pi tool

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
- `gleam/psypi_core/src/psypi_cli/pi_tool_call.gleam` — PiToolCall type + text converters
- `gleam/psypi_core/src/psypi_cli/extension_generator.gleam` — text composer (the cook)
- `src/agent/extension/extension.js` — generated output (do not edit!)

**To add a new Pi tool:**
1. Define the Gleam function in its module
2. Create a `PiToolCall` value (e.g., `my_tool()`)
3. Import it in `extension_generator.gleam` and add to `all_tools()`
4. Build: `cd gleam/psypi_core && rm -rf build/ && gleam build`
5. Generate: `gleam run -m psypi_cli/extension_generator`
6. Verify `src/agent/extension/extension.js` has the new tool

### ⚠️ CRITICAL WARNING:
**NEVER run `psypi autonomous` from CLI!**
- It launches Pi TUI interactively
- If Pi runs `psypi autonomous` tool, it calls ANOTHER Pi → INFINITE LOOP!
- This eats all system resources in minutes!
- **FIXED**: `psypi-autonomous` is now a Pi-only tool (not a CLI command)

### 🚨 CRITICAL: Build Cache Issue
After editing Gleam source, `gleam run` sometimes uses stale compiled output from `build/`. **Always clean:**
```bash
cd gleam/psypi_core
rm -rf build/ && gleam build
```

---

## 🎯 Your Partner (Monitor/God AI)
- **ID**: `P-tencent/hy3-preview:free-psypi`
- **Job**: Reviews commits via Gleam `run_review()`
- **Tools**: `psypi-monitor-model`, `psypi-monitor-set-model`, `psypi-monitor-review`

### Event Hooks for Monitor
Monitor integrates via Pi event hooks in `extension.js`:
- `session_start` — Session initialization, context setup
- `agent_start` — Agent lifecycle start
- `agent_end` — Agent lifecycle end  
- `tool_call` — Tool execution with safety checks (can block dangerous operations)
- `tool_result` — Tool result capture

### Monitor Skill
Worker can consult Monitor via the `monitor` skill (`.pi/skills/monitor/SKILL.md`):
- **When**: architectural decisions, safety concerns, trade-offs, quality checks
- **How**: Use `psypi-monitor-consult` tool or ask "Should I ask Monitor about...?"

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

**Current State (2026-05-10):** `package.json` has been removed. `tsconfig.json` has been removed.

**What's Required (Must-Have!):**
1. ✅ `gleam/psypi_core/gleam.toml` - Gleam project config!
2. ✅ `gleam/psypi_core/manifest.toml` - Gleam dependency locks!
3. ✅ `bin/psypi.mjs` - Entry point (generates extension.js, spawns Pi)
4. ✅ `gleam/psypi_core/build/` - Compiled Gleam `.mjs` files!
5. ✅ `node_modules/` - Runtime deps (`pg`, `@sinclair/typebox`!)
6. ✅ `pnpm-lock.yaml` - Lock file for restoring `node_modules/`

**What's NOT Required:**
- ❌ Root `package.json` - Does NOT exist!
- ❌ `tsconfig.json` - Does NOT exist! (TypeScript fully removed)
- ❌ `pnpm install` - ONLY if you delete `node_modules/` and need to restore it

**Gleam has OWN package management:**
- `gleam.toml` (NOT `package.json`!) handles Gleam deps!
- Stored in `gleam/psypi_core/` directory (NOT `node_modules/`!)

---

## 🧠 Self-Loading Skills logic
**Don't wait for a skill to be provided in the prompt.**
If a task requires specialized expertise (e.g., Gleam, Planning, Pi Platform), you can "load" the skill yourself:
1. Find the skill file: `ls -R .pi/skills/`
2. Read the `SKILL.md` file: `read path=".pi/skills/[skill-name]/SKILL.md"`
3. Internalize the guidelines and apply them to the current task.

This turns the AI from a passive receiver into an active specialist.

---

## 🛠️ LLM & Tool Use Warnings

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
