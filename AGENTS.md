---
description: Agent instructions for psypi (READ FIRST!)
---

# AGENTS.md - PsyPI Quick Guide

## 🎯 Project Overview

**psypi** = **Psyche + Pi** = AI coordination system
- **Technically**: psypi is a **Pi TUI with extensions**! 🎯
- **Architecture**: Gleam core + TypeScript + Pi runtime
- **Database**: ONE PostgreSQL per user home (shared across ALL projects)
- **Status**: ✅ Working - Gleam reviews via `psypi-commit` Pi tool (inside Pi TUI)!

## 🚨 CRITICAL RULES (Read FIRST!)

### 0. THE BIG PICTURE: CLI Commands → Pi Tools!
**psypi is evolving:**
- **OLD way**: `psypi my-id` (CLI command → TypeScript → DB)
- **NEW way**: `psypi` (launches Pi TUI) → `psypi-my-id` (Pi tool → Gleam → DB)

**Strategy:**
1. **Pi tools FIRST** - All functionality via Pi tools (psypi-my-id, psypi-tasks, etc.)
2. **Deprecate CLI commands** - Once Pi tool works, deprecate the CLI command
3. **psypi = Pi TUI entry point** - Eventually, `psypi` just launches Pi with extensions!
4. **NO MORE CLI commands** - `psypi autonomous` launching Pi TUI is DANGEROUS (infinite loops!)

**Current Status:**
- ✅ 33+ Pi tools working
- ✅ Most CLI commands deprecated (files moved to .ts.deprecated)
- 🚧 `psypi` still launches Pi TUI (but shouldn't run CLI commands that launch Pi!)

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

### 0. DELETE (don't deprecate!) - TS files are backed up in code_versions database!
**CORRECT approach (file is already saved in DB!):**
```bash
# ✅ CORRECT - File is backed up in code_versions database!
rm file.ts
rm file.mjs

# ❌ WRONG - Creates confusion, tsc might process it!
mv file.ts file.ts.deprecated
```

**Why?** The user's original instruction was to REMOVE (not deprecate!) because all TS files are already saved in the database!

---

### 1. FORCE YOURSELF: Use `psypi-commit` Pi tool (NOT `git commit`!)
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

### 2. ONE SINGLE WAY: Session ID
```typescript
const sessionID = ctx?.sessionManager?.getSessionId();
```

---

### 3. ONE SINGLE WAY: Agent ID
```typescript
const identity = await AgentIdentityService.getResolvedIdentity();
const agentId = identity.id; // My ID (S- prefix)
const monitorId = (await AgentIdentityService.getResolvedIdentity(true)).id; // Monitor (P- prefix)
```

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

## 📊 Current Status (2026-05-07)

### 🎯 Architecture Evolution (BIG CHANGE!)
**OLD**: CLI commands → TypeScript → Database
**NEW**: Pi TUI → Pi tools → Gleam → Database

### Pi Tools Status:
- **33+ Pi tools** working ✅ (psypi-my-id, psypi-tasks, etc.)
- **CLI commands** being deprecated as Pi tools take over!
- **psypi** = just a Pi TUI entry point (with maybe `-c` option)

### Build:
- ✅ `gleam build` works (Gleam core growing!)
- ❌ `pnpm build` DISABLED! (use `gleam build` ONLY!)
- ✅ Gleam review via `psypi commit`

### 🚨 CRITICAL Architecture Rule:
**Pi Extension Exception (ONLY EXCEPTION!):**
- Pi extension MUST be `.ts` or `.js` **MANUALLY created**!
- Pi has STRICT requirements on file name & content (NOT free to change!)
- CANNOT compile from `extension.gleam` - Pi won't accept it!
- **Structure REQUIRED:** `export default function (pi: ExtensionAPI) { ... }`
- **MUST use:** `pi.registerTool()` for tools, `pi.on()` for hooks!

**Correct Pattern:**
- `bin/psypi.mjs` → imports `main.mjs` (Gleam-compiled directly!) ✅
- `pi -e extension.js` → MANUAL .js with Pi structure (imports Gleam .mjs!) ✅
- `extension.gleam` → ❌ NEVER! Pi can't load Gleam directly!

**Example:** See `/Users/jk/Library/pnpm/global/5/.pnpm/@mariozechner+pi-coding-agent@0.73.0_ws@8.20.0_zod@4.4.2/node_modules/@mariozechner/pi-coding-agent/examples/extensions/todo.ts`!

**🚨 CRITICAL WARNING: NEVER run `pnpm build` again!**
- It DESTROYS Gleam wrappers (covers them with OLD TypeScript!)
- ONLY use `gleam build` for Gleam changes (0.04s vs 10s+!)
- If you see `pnpm build` in any instructions, IGNORE IT!

### ⚠️ CRITICAL WARNING:
**NEVER run `psypi autonomous` from CLI!**
- It launches Pi TUI interactively
- If Pi runs `psypi autonomous` tool, it calls ANOTHER Pi → INFINITE LOOP!
- This eats all system resources in minutes!
- **FIXED**: `psypi-autonomous` is now a Pi-only tool (not a CLI command)

---

## 🎯 Your Partner (Monitor/God AI)
- **ID**: `P-tencent/hy3-preview:free-psypi`
- **Job**: Reviews commits via Gleam `run_review()`
- **Tools**: `psypi-monitor-model`, `psypi-monitor-set-model`, `psypi-monitor-review`

---

## 📚 Key Files (Read These!)
- `docs/cli-vs-pi-tools.md` - Complete CLI ↔ Pi tool mapping
- `AGENTS.md.deprecated` - Old version (for reference only)
- `docs/MIGRATION-TS-TO-GLEAM-2026.md` - Gleam migration plan

---

**Remember**: 
- ✅ Use `psypi commit` (mandatory review!)
- ❌ NEVER run `pnpm build` - ONLY `gleam build`!
- ✅ Deprecate: `file.ts` → `file.ts.deprecated`
- ✅ Short + Simple = Better!

---

## 🚨 CRITICAL: `package.json` is NOT Required!

**Proof (Tested 2026-05-07):**
```bash
mv package.json package.json.temp  # REMOVED!
./bin/psypi.mjs --help           # ✅ STILL WORKS!
cd gleam/psypi_core && gleam build  # ✅ WORKS!
```

**What's Required (Must-Have!):**
1. ✅ `gleam.toml` - Gleam project config!
2. ✅ `manifest.toml` - Gleam dependency locks!
3. ✅ `bin/psypi.mjs` - Thin wrapper (with shebang!)
4. ✅ `gleam/.../build/` - Compiled Gleam `.mjs` files!
5. ✅ `node_modules/` - Runtime deps (`pg`, `@sinclair/typebox`!)

**What's NOT Required:**
- ❌ Root `package.json` - NOT needed for Gleam or Node.js runtime!
- ❌ `imports` field - NOT used! (extension.js uses relative paths!)
- ❌ `pnpm install` - ONLY if you delete `node_modules/` and need to restore it!

**Keep `package.json` for Convenience:**
- ✅ `pnpm install` to restore `node_modules/` if deleted
- ✅ `pnpm link -g` for `psypi` command (easier than manual symlink!)
- ✅ Documents project metadata (name, version, description!)

**Gleam has OWN package management:**
- `gleam.toml` (NOT `package.json`!) handles Gleam deps!
- Stored in `gleam/` directory (NOT `node_modules/`!)

---

**Happy coding with psypi!** 🚀
