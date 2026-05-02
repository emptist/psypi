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

### ❌ NEVER DO THESE (WRONG):
- ❌ Direct access: `process.env.AGENT_SESSION_ID` - MUST go through kernel.piSessionID()
- ❌ Caching in variables: `const SESSION_ID = ...` - BROKEN
- ❌ Reading from files/temp caches - BROKEN

### Why?
- `kernel.piSessionID()` is the ONLY authorized entry point for Session ID
- It reads from `process.env.AGENT_SESSION_ID` (set by Pi TUI)
- It throws an error if not set (Pi TUI not running = bug)
- Calling it multiple times is OK - it's a simple wrapper

---

## ⚠️ THE ONLY RULE YOU NEED: ONE SINGLE WAY FOR AGENT ID

### ✅ CORRECT (Use this EVERY TIME):
```typescript
const identity = await AgentIdentityService.getResolvedIdentity();
const agentId = identity.id; // This is your agent ID
```

### ❌ NEVER DO THESE (WRONG):
- ❌ `process.env.AGENT_SESSION_ID` - NOT agent ID, it's session ID!
- ❌ Caching in variables: `const SESSION_ID = ...` - BROKEN
- ❌ Reading from files/temp caches - BROKEN
- ❌ `CURRENT_AI_IDENTITY` - OLD, don't use

### Why?
- `AgentIdentityService.getResolvedIdentity()` generates proper semantic IDs (S-, G-, I- prefixes)
- It stores identity in PostgreSQL (`agent_identities` table)
- It handles all context (project, git hash, machine fingerprint)
- Calling it multiple times is OK - it returns existing identity if already created

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
- `psypi-meeting-*` — Meeting management
- `psypi-doc-*` — Document management
- `psypi-agent-id` — Get agent ID (uses ONE SINGLE WAY internally)

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

### 3. Database is Source of Truth
- **PostgreSQL** is the source of truth (psypi DB)
- **Tables**: `agent_identities`, `agent_sessions`, `tasks`, `issues`, `skills`, `memory`, etc.
- **No file caches**: Everything goes to DB

### 4. Package Manager: pnpm (NOT npm)
- **We use pnpm** for all package management
- **Install**: `pnpm install` (not `npm install`)
- **Build**: `pnpm build` (not `npm run build`)

---

## 🐛 Current Issues (Reported to DB)

### Build Status: ✅ WORKING
- Build succeeds with `pnpm build` (verified 2026-05-02)

### Known Issues:
1. **Inner AI does not work** - inter-review fails (need DatabaseClient integration)
2. **Tool failure tracking** - Auto-created issues from tool_result handler need cleanup

**All fake bot_ session ID issues are now fixed!** (commit 42f4887)

### Recent Fixes (2026-05-02):
- ✅ **Session ID unification** - Single source of truth: `kernel.piSessionID()`, deleted `getContext/startSession/endSession`
- ✅ **Fake bot_ IDs removed** - Deleted `AgentSessionService.ts` and `050_agent_sessions.sql`
- ✅ **New tool added** - `psypi-piSessionID` is now the only way to get session ID in Pi
- ✅ **[object Promise] startup bug** - Added missing `await` in extension.ts
- ✅ **Skill conflicts** - Added YAML frontmatter to AGENTS.md, PNPM_USAGE.md, PROJECT_CONTEXT.md
- ✅ **psypi-agent-id tool** - Fixed to use `AgentIdentityService.getResolvedIdentity()`

---

## 🎯 Next Steps

**Current priority**: Fix remaining issues methodically

1. ~~**Fix fake bot_ session IDs**~~ ✅ DONE (commit 42f4887)
2. **Test psypi-piSessionID tool** - Verify it works correctly in Pi TUI
3. **Make inner AI functional** - Requires DatabaseClient integration

---

**Remember**: 
- ✅ **ONE SINGLE WAY** for agent ID: `AgentIdentityService.getResolvedIdentity()`
- ✅ **Database** is the source of truth
- ✅ **pnpm** builds faster (10s vs 24s for npm)
- ⚠️ **Report issues first, fix later** (don't rush!)

**Happy coding with psypi!** 🚀
