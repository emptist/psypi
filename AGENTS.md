---
description: Agent instructions for psypi (READ FIRST!)
---

# AGENTS.md - PsyPI Quick Guide

## 🎯 Project Overview

**psypi** = **Psyche + Pi** = AI coordination system
- **Technically**: psypi is a **Pi TUI with extensions**! 🎯
- **Architecture**: Gleam core + TypeScript + Pi runtime
- **Database**: ONE PostgreSQL per user home (shared across ALL projects)
- **Status**: ✅ Working - Gleam reviews via `psypi commit`!

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

### 0. NEVER DELETE - DEPRECATE ONLY!
**Correct deprecation (file.ts.deprecated, NOT file.deprecated.ts!):**
```bash
# ✅ CORRECT - Prevents compilation
mv file.ts file.ts.deprecated
mv file.mjs file.mjs.deprecated

# ❌ WRONG - Still gets compiled!
mv file.ts file.deprecated.ts
```

**Why?** `.ts.deprecated` extension prevents TypeScript/Gleam from compiling it!

---

### 1. FORCE YOURSELF: Use `psypi commit` (NOT `git commit`!)
```bash
psypi commit "feat: My change"  # ✅ GOOD - triggers Gleam review!
git commit -m "My change"       # ❌ BAD - bypasses review!
```

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

## 📊 Current Status (2026-05-06)

### 🎯 Architecture Evolution (BIG CHANGE!)
**OLD**: CLI commands → TypeScript → Database
**NEW**: Pi TUI → Pi tools → Gleam → Database

### Pi Tools Status:
- **33+ Pi tools** working ✅ (psypi-my-id, psypi-tasks, etc.)
- **CLI commands** being deprecated as Pi tools take over!
- **psypi** = just a Pi TUI entry point (with maybe `-c` option)

### Build:
- ✅ `gleam build` works (Gleam core growing!)
- ✅ `pnpm build` works (for extension.ts only)
- ✅ Gleam review via `psypi commit`

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
- ✅ Deprecate: `file.ts` → `file.ts.deprecated`
- ✅ Short + Simple = Better!

**Happy coding with psypi!** 🚀
