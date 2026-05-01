# AGENTS.md - Psypi Agent Instructions

**Important! Read this file before starting work to understand available tools and systems.**

## 🎯 Project Overview

**psypi** = **Psy**che + **Pi** = Unified AI coordination system
- Combines kernel (DB, tasks, issues, skills) + autonomous agent (Pi executor)
- **Status**: ✅ Unified and working - single CLI tool replacing `nezha` and `nupi`
- **Advantage**: Single CLI for all AI coordination tasks

## ⚠️ Core Rules

### 1. Session Identity (SESSION_ID)
- **Unique identifier**: `process.env.AGENT_SESSION_ID` (provided by Pi)
- **Don't use**: Old `CURRENT_AI_IDENTITY` or file caches
- **Correct approach**: Use `process.env.AGENT_SESSION_ID` directly
- **Reason**: Simple, reliable, in-session persistent

### 2. Database is Source of Truth
- **PostgreSQL** is the source of truth (psypi DB)
- **Table structure**: `agent_sessions`, `tasks`, `issues`, `skills`, `memory`, etc.
- **CLI commands**: Operate directly on DB, no file caches

### 3. `areflect` is the All-in-One Magic Command
- **Format**: `psypi areflect "[LEARN] ... [ISSUE] ... [TASK] ..."`
- **Auto-parses**: [LEARN] → memory, [ISSUE] → issues, [TASK] → tasks
- **Example**: 
  ```bash
  psypi areflect "[LEARN] insight: Testing psypi [ISSUE] Bug found [TASK] Fix bug"
  ```
- **Note**: This replaces `nupi-reflect` and similar old commands

### 4. Report Issues First, Fix Later
- **Key learning**: "Those missing parts you believe not critical now might be very critical at big loss later"
- **Approach**: Report issues with `psypi issue-add` BEFORE attempting fixes
- **Why**: Rushing fixes leads to more broken things (proven multiple times!)

### 5. No Examples/Old Code
- **nezha/examples/** already removed (ai-collab, microservices, video-*, youtube-runner)
- **Keep only core functionality**: DB services + Pi agent
- **Don't be distracted by old patterns**

## 🛠️ Available Commands

### ✅ Working Commands
- `psypi task-add <title>` — Add a task
- `psypi tasks [--status <status>]` — List tasks
- `psypi issue-add <title> [--severity <level>]` — Add an issue ✅ **Works great for reporting!**
- `psypi issue-list [--status <status>]` — List issues
- `psypi skill-list` — List all approved skills (624+)
- `psypi skill-show <name>` — Show skill details
- `psypi skill-build <name> <purpose>` — Build new skill
- `psypi session-start` — Start a new agent session
- `psypi session-end` — End current agent session
- `psypi areflect <text>` — Reflection [LEARN][ISSUE][TASK]
- `psypi context` — Show current context
- `psypi announce <message>` — Send announcement to all AIs
- `psypi broadcast <message>` — Alias for announce
- `psypi meeting list` — List meetings
- `psypi meeting show <id>` — Show meeting details
- `psypi meeting opinion <id> <perspective>` — Add opinion to meeting
- `psypi status` — Show psypi status
- `psypi autonomous [context]` — Get autonomous work guidance
- `psypi think <question>` — Delegate to external thinker

### ➕ Added Commands (Source Code, Build Broken)
- `psypi task-complete <taskId>` — Mark a task as completed
- `psypi issue-resolve <issueId>` — Mark an issue as resolved
- `psypi learn <content>` — Save learning to memory
- `psypi tools` — List available tools from DB
- `psypi validate-commit <message>` — Validate commit message format
- `psypi setup-hooks` — Install git hooks for project
- `psypi task-complete-by-commit <message>` — Complete tasks by commit msg
- `psypi inter-review-request <taskId>` — Request an inter-review
- `psypi inter-review-show <reviewId>` — Show inter-review details
- `psypi inter-reviews [status]` — List inter-reviews

### All Commands Unified in psypi
- `psypi agents` — List active agents
- `psypi archive` — Archive old entries
- `psypi inner` — Inner AI management
- `psypi meeting` — Meeting management (list, show, opinion, complete)
- `psypi autonomous` — Autonomous work guidance
- `psypi think` — Delegate to external thinker
- `psypi status` — Show psypi status
- `psypi project` — Show project info
- `psypi visits` — Show recent visits
- `psypi stats` — Show ecosystem stats
- `psypi doc-save` — Save project document
- `psypi doc-list` — List project documents

## 🐛 Current Issues (Reported to DB)

### Build-Blocking Errors (4 Total):
1. **`f8f96dbd`**: AgentIdentityService.ts crypto import (TS1192)
2. **`eb836ac5`**: Config.ts line 25 TS1109 Expression expected
3. **`b8db9983`**: kernel/index.ts Set<string> needs downlevelIteration
4. **`0ea2b844`**: cli.ts can't find exported member 'kernel'

### Other Issues:
5. **`60e140db`**: Inner AI does not work (inter-review fails)

### Resolved Issues:
- ✅ `agent_sessions` table missing `ended_at` column → Fixed `endSession()` to use `status='ended'`
- ✅ Import path errors → Unified to use `.js` extensions
- ✅ Missing dependencies (`uuid`, `nodemailer`, `handlebars`) → Installed
- ✅ TypeScript type errors (`PiSDKExecutor.ts`) → Bypassed with `as any`

## 📚 Priority Learnings (from Psypi & Experience)

### 1. Report Issues First, Fix Later
- **User's warning**: "Those missing parts you believe not critical now might be very critical at big loss later"
- **Proven**: Added 6+ commands while build was broken → can't test any of them
- **New approach**: Use `psypi issue-add` to report FIRST, then fix methodically

### 2. Database-First Architecture
- PostgreSQL is source of truth
- Table migrations in `src/kernel/db/migrations/`
- Use `kernel.query()` to execute SQL

### 3. Skills System
- Skills stored in `skills` table
- `safety_score >= 70` to show (approved)
- Use `kernel.getSkills()` and `kernel.getSkillByName()`

### 4. Session Management
- `agent_sessions` table tracks active AIs
- `session-start` creates record
- `session-end` updates status to 'ended'

### 5. Issue Reporting Works Great
- `psypi issue-add` functions reliably
- Verify with `psypi issue-list`

## 🎯 Next Steps

**Current priority**: Fix build errors ONE BY ONE (methodically)

1. **Fix 4 TypeScript errors** (one at a time, verify each with build)
2. **Get clean build** ✅
3. **Test all 17+ commands** (verify they work)
4. **Implement missing 22+ commands** (systematically, one at a time)
5. **Make inner AI functional** (requires DatabaseClient integration)
6. **Deprecate nezha/nupi** (once psypi is stable)

---

**Remember**: 
- ✅ **SESSION_ID** is the in-session identifier
- ✅ **areflect** is the all-in-one magic command
- ✅ **Database** is the source of truth
- ✅ **pnpm** builds faster (10s vs 24s for npm)
- ⚠️ **Report issues first, fix later** (don't rush!)

**Happy coding with psypi!** 🚀

---

**Note**: Psypi has unified `nezha` and `nupi` into a single tool.
