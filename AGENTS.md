---
description: Agent instructions and guidelines for working with psypi project
---

# AGENTS.md - PsyPI Agent Instructions

**Important! Read this file before starting work to understand available tools and systems.**

## 🎯 Project Overview

**psypi** = **Psy**che + **Pi** = Unified AI coordination system
- Combines kernel (DB, tasks, issues, skills) + autonomous agent (Pi executor)
- **Status**: ✅ Unified and working - single CLI tool replacing `nezha` and `nupi`
- **Advantage**: Single CLI for all AI coordination tasks

---

## ⚠️ THE ONLY RULE YOU NEED: ONE SINGLE WAY FOR SESSION ID

### ✅ CORRECT (Use this EVERY TIME):
```typescript
const sessionID = await kernel.piSessionID(); // This is your session ID
```

### How it works internally (TWO METHODS):
`kernel.piSessionID()` uses shared utility `getPiSessionID()` from `src/kernel/utils/session.ts`:
1. **`process.env.AGENT_SESSION_ID`** - Set by Pi TUI when launching extension
2. **Parse from JSONL file** - Reads most recent `~/.pi/agent/sessions/<project>/<timestamp>_<sessionId>.jsonl`

### ❌ NEVER DO THESE (WRONG):
- ❌ Direct access: `process.env.AGENT_SESSION_ID` - MUST go through kernel.piSessionID()
- ❌ `ctx.sessionManager.getSessionId()` - Pi API, but still use kernel.piSessionID()
- ❌ Caching in variables: `const SESSION_ID = ...` - BROKEN
- ❌ Reading from files/temp caches - BROKEN (except via kernel.piSessionID())

### Why?
- `kernel.piSessionID()` is the ONLY authorized entry point for Session ID
- It tries TWO methods internally (env var first, JSONL fallback)
- It throws an error if not set (Pi TUI not running = bug)
- Calling it multiple times is OK - it's a simple wrapper

---

## ⚠️ THE ONLY RULE YOU NEED: ONE SINGLE WAY FOR AGENT ID

### ✅ CORRECT (Use this EVERY TIME):
```typescript
const identity = await AgentIdentityService.getResolvedIdentity();
const agentId = identity.id; // This is your agent ID
// For partner/permanent ID: getResolvedIdentity(true)
const partnerId = (await AgentIdentityService.getResolvedIdentity(true)).id;
```

### ❌ NEVER DO THESE (WRONG):
- ❌ `process.env.AGENT_SESSION_ID` - NOT agent ID, it's session ID!
- ❌ `process.env.AGENT_ID` - use getResolvedIdentity() instead!
- ❌ `getCurrentAgentId()` - DELETED, don't use
- ❌ `kernel.agentID()` - REMOVED, don't use
- ❌ Caching in variables: `const AGENT_ID = ...` - BROKEN
- ❌ Reading from files/temp caches - BROKEN
- ❌ `CURRENT_AI_IDENTITY` - OLD, don't use

### Why?
- `AgentIdentityService.getResolvedIdentity()` is the ONLY authorized entry point for Agent ID
- Generates proper semantic IDs: `S-` (session), `P-` (permanent/partner), `G-` (global)
- Stores identity in PostgreSQL (`agent_identities` table)
- Handles all context (project, git hash, machine fingerprint)
- Calling it multiple times is OK - returns existing identity if already created

### Quick Commands:
- **My ID**: `psypi my-id` (CLI) or `psypi-agent-id` (Pi tool)
- **Partner ID**: `psypi partner-id` (CLI) or `psypi-partner-id` (Pi tool)
  - Partner = permanent/monitor/reviewer (God AI)
  - Uses `P-` prefix (e.g., `P-tencent/hy3-preview:free-psypi`)

---

## 🛠️ Available Commands

### ✅ Working Commands
- `psypi task-add <title>` — Add a task
- `psypi tasks [--status <status>]` — List tasks
- `psypi issue-add <title> [--severity <level>]` — Add an issue
- `psypi issue-list [--status <status>]` — List issues
- `psypi skill-list` — List all approved skills (624+)
- `psypi skill-show <name>` — Show skill details
- `psypi areflect <text>` — Reflection [LEARN][ISSUE][TASK] auto-parse
- `psypi commit <message>` — Git commit with mandatory inter-review
- `psypi my-session-id` — Get Pi session ID (UUID v7, single source of truth)
- `psypi autonomous [context]` — Get autonomous work guidance
- `psypi think <question>` — Delegate to external thinker
- `psypi status` — Show psypi status
- `psypi project` — Show project info
- `psypi visits` — Show recent visits
- `psypi stats` — Show ecosystem stats

### In Pi TUI (via psypi extension):
- `psypi-think` — Delegate complex reasoning
- `psypi-tasks` — Check pending tasks
- `psypi-autonomous` — Get work guidance
- `psypi-piSessionID` — Get Pi session ID (UUID v7)
- `psypi-agent-id` — Get agent ID (uses ONE SINGLE WAY internally)
- `psypi-partner-id` — Get partner/monitor ID (permanent God AI)
- `psypi-meeting-*` — Meeting management
- `psypi-doc-*` — Document management

---

## 📚 Key Learnings

### 1. Report Issues First, Fix Later
- **Rule**: "Those missing parts you believe not critical now might be very critical at big loss later"
- **Approach**: Report issues with `psypi issue-add` BEFORE attempting fixes
- **Why**: Rushing fixes leads to more broken things (proven multiple times!)

### 2. `areflect` is the All-in-One Magic Command
- **Format**: `psypi areflect "[LEARN] ... [ISSUE] ... [TASK] ..."`
- **Auto-parses**: [LEARN] → memory, [ISSUE] → issues, [TASK] → tasks
- **Example**: 
  ```bash
  psypi areflect "[LEARN] insight: Testing psypi [ISSUE] Bug found [TASK] Fix bug"
  ```

### 3. Database First
- **PostgreSQL** is the database (psypi DB)
- **Table of all tables**: `table_documentation`, use and maintain it
- **Tables**: `agent_identities`, `agent_sessions`, `tasks`, `issues`, `skills`, `memory`, etc.
- **No file caches**: Everything goes to DB

### 4. Package Manager: pnpm (NOT npm)
- **We use pnpm** for all package management
- **Install**: `pnpm install` (not `npm install`)
- **Build**: `pnpm build` (not `npm run build`)

### 5. Git Commit with Inter-Review
- **psypi commit**: instead of using git commit directly
  - `psypi commit <message>` — Git commit with mandatory inter-review
---

## 🐛 Current Issues (Reported to DB)

### Build Status: ✅ WORKING
- Build succeeds with `pnpm build` (verified 2026-05-02)
- see [PNPM_USAGE.md](docs/PNPM_USAGE.md)

### Known Issues:
1. **Inner AI needs to be shift to use Pi agent** - shifting will start after database migration
2. **Tool failure tracking** - Auto-created issues from tool_result handler need cleanup

**All fake bot_ session ID issues are now fixed!** (commit 42f4887)

### Recent Fixes (2026-05-03):
- ✅ **Session ID TWO METHODS** - `kernel.piSessionID()` now supports TWO ways:
  - `process.env.AGENT_SESSION_ID` (primary, set by Pi TUI)
  - Parse from JSONL file (fallback for resilience)
- ✅ **Extension session_start fixed** - Now gets session ID from `ctx.sessionManager.getSessionId()`
- ✅ **Shared utility created** - `src/kernel/utils/session.ts` with `getPiSessionID()`
- ✅ **No more fake IDs** - Removed random UUID generation, proper error reporting
- ✅ **AgentIdentityService fixed** - Uses `getPiSessionID()` instead of direct env access

---

## 🎯 Next Steps

**Current priority**: Fix remaining issues methodically

1. ~~**Fix fake bot_ session IDs**~~ ✅ DONE (commit 42f4887)
2. ~~**Simplify agent ID system**~~ ✅ DONE (single source of truth)
3. **Test psypi tools** - Verify `psypi-agent-id` and `psypi-partner-id` work in Pi TUI
4. **Make inner AI agent** - Requires shift to use Pi agent

**Current IDs:**
- **My ID**: `S-psypi-psypi` (session-based, via `getResolvedIdentity()`)
- **Partner ID**: `P-tencent/hy3-preview:free-psypi` (permanent/monitor, via `getResolvedIdentity(true)`)

---

**Remember**: 
- ✅ **ONE SINGLE WAY** for agent ID: `AgentIdentityService.getResolvedIdentity()`
  - `getResolvedIdentity()` = my ID (S- prefix)
  - `getResolvedIdentity(true)` = partner ID (P- prefix)
- ✅ **ONE SINGLE WAY** for session ID: `kernel.piSessionID()`
- ✅ **Database** first
- ✅ **pnpm** builds faster (10s vs 24s for npm)
- ✅ **psypi commit**: instead of using git commit directly
  - `psypi commit <message>` — Git commit with mandatory inter-review
- ⚠️ **Report issues first, fix later** (don't rush!)

**Happy coding with psypi!** 🚀
