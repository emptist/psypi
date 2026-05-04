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

## 📊 Current Status (2026-05-04)

### Pi Tools Status:
- **33 CLI commands** have Pi tools ✅
- **2 CLI commands** without Pi tools: `provider-set-key`, `help`
- **3 Pi tools** without CLI: `psypi-doc-restore`, `psypi-skill-search`, `psypi-broadcast-list`

### Build:
- ✅ `pnpm build` works (Gleam + TypeScript)
- ✅ Gleam review via `psypi commit` (score: 70/100)

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
