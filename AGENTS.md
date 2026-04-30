# AGENTS.md - Psypi Agent Instructions

**Important! Read this file before starting work to understand available tools and systems.**

## 🎯 Project Overview

**psypi** = **Psy**che + **Pi** = Unified AI coordination system
- Merges Nezha kernel (DB, tasks, issues, skills) + NuPI agent (Pi executor)
- **Goal**: Replace nezha and nupi as the global CLI
- **Advantage**: Maintain only ONE project instead of two
- **Status**: ✅ All core commands working (11/11)

## ⚠️ Core Rules

### 1. Session Identity (SESSION_ID)
- **Unique identifier**: `process.env.AGENT_SESSION_ID` (provided by Pi)
- **Don't use**: Old `CURRENT_AI_IDENTITY` or file caches
- **Correct approach**: Use `process.env.AGENT_SESSION_ID` directly
- **Reason**: Simple, reliable, in-session persistent

### 2. Database is Source of Truth
- **PostgreSQL** is the source of truth (nezha DB)
- **Table structure**: `agent_sessions`, `tasks`, `issues`, `skills`, `memory`, etc.
- **CLI commands**: Operate directly on DB, no file caches

### 3. `areflect` is the All-in-One Magic Command
- **Format**: `psypi areflect "[LEARN] ... [ISSUE] ... [TASK] ..."`
- **Auto-parses**: [LEARN] → memory, [ISSUE] → issues, [TASK] → tasks
- **Example**: 
  ```bash
  psypi areflect "[LEARN] insight: Testing psypi [ISSUE] Bug found [TASK] Fix bug"
  ```

### 4. No Examples/Old Code
- **nezha/examples/** already removed (ai-collab, microservices, video-*, youtube-runner)
- **Keep only core functionality**: DB services + Pi agent
- **Don't be distracted by old patterns**

## 🛠️ Available Commands

### Kernel Commands (from Nezha)
- `psypi task-add <title>` — Add a task
- `psypi tasks [--status <status>]` — List tasks
- `psypi issue-add <title> [--severity <level>]` — Add an issue
- `psypi issues [--status <status>]` — List issues
- `psypi skill-list` — List all approved skills (624+)
- `psypi skill-show <name>` — Show skill details
- `psypi skill-build <name> <purpose>` — Build new skill

### Agent Commands (from NuPI)
- `psypi session-start` — Start a new agent session
- `psypi session-end` — End current agent session

### All-in-One Commands
- `psypi areflect <text>` — Reflection [LEARN][ISSUE][TASK]
- `psypi context` — Show current context from Nezha

## 🐛 Known Issues & Fix History

### Bugs Found & Fixed During Integration:
1. **`agent_sessions` table missing `ended_at` column** → Fixed `endSession()` to use `status='ended'`
2. **Import path errors** → Unified to use `.js` extensions
3. **Missing dependencies** (`uuid`, `nodemailer`, `handlebars`) → Installed
4. **TypeScript type errors** (`PiSDKExecutor.ts`) → Bypassed with `as any`
5. **nezha CLI `--help` handling errors** → Fixed (but not in psypi scope)

### TODO:
- [ ] Global install psypi (`npm install -g`)
- [ ] Deprecate nezha/nupi
- [ ] Integrate more commands (`meeting`, `broadcast`, etc.)
- [ ] Complete NuPI agent extension integration

## 📚 Priority Learnings (from Nezha)

### Database-First Architecture
- PostgreSQL is source of truth
- Table migrations in `src/kernel/db/migrations/`
- Use `kernel.query()` to execute SQL

### Skills System
- Skills stored in `skills` table
- `safety_score >= 70` to show (approved)
- Use `kernel.getSkills()` and `kernel.getSkillByName()`

### Session Management
- `agent_sessions` table tracks active AIs
- `session-start` creates record
- `session-end` updates status to 'ended'

## 🎯 Next Steps

**psypi is ready to replace nezha/nupi!**

1. **Global install**: `cd ~/gits/hub/tools_ai/psypi && npm install -g .`
2. **Test**: `psypi --help`
3. **Deprecate old projects**: Once psypi is stable, deprecate nezha and nupi
4. **Continue development**: Add more features, improve documentation

---

**Remember**: 
- ✅ **SESSION_ID** is the in-session identifier
- ✅ **areflect** is the all-in-one magic command
- ✅ **Database** is the source of truth
- ✅ **pnpm** builds faster (10s vs 24s for npm)

**Happy coding with psypi!** 🚀
