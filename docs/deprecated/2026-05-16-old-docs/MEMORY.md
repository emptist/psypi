# MEMORY.md - psypi Long-Term Memory

## Core Principles

### 1. Database is Source of Truth
- PostgreSQL is the **only** source of truth (nezha DB)
- No file caches, no `.nezha/` directories
- Every state lives in DB tables

### 2. Session Identity is Simple
- `process.env.AGENT_SESSION_ID` is the **only** in-session identifier
- No `CURRENT_AI_IDENTITY`, no static variables
- Session identity changes when you `cd` to different projects

### 3. `areflect` is the Magic Command
- All-in-one: `[LEARN] [ISSUE] [TASK]` parsing
- Example: `psypi areflect "[LEARN] insight [ISSUE] title [TASK] title"`
- Saves to `memory`, `issues`, `tasks` tables automatically

### 4. No Dead Code / Old Examples
- `nezha/examples/` removed (ai-collab, microservices, video-*, youtube-runner)
- Only core functionality: DB services + Pi agent
- Don't be distracted by old patterns

### 5. Fast Builds with pnpm
- pnpm > npm: 10s vs 24s build time
- Use `pnpm install`, `pnpm run build`
- Keep `pnpm-lock.yaml` committed

## Table Structures (Key Tables)

### `agent_sessions`
- **Purpose**: Track active AI agents
- **Columns**: `id`, `started_at`, `last_heartbeat`, `status`, `agent_type`, `identity_id`
- **Note**: No `ended_at` column! Use `status='ended'` instead

### `tasks`
- **Purpose**: Task scheduling and execution
- **Columns**: `id`, `title`, `description`, `status`, `priority`, `created_by`
- **Status**: PENDING, COMPLETED, etc.

### `issues`
- **Purpose**: Issue tracking system
- **Columns**: `id`, `title`, `severity`, `status`, `created_by`
- **Severity**: critical, high, medium, low

### `skills`
- **Purpose**: On-demand skill loading for AIs
- **Columns**: `id`, `name`, `status`, `safety_score`, `instructions`
- **Note**: `safety_score >= 70` to show (approved skills)

### `memory`
- **Purpose**: Knowledge management system
- **Columns**: `id`, `content`, `tags`, `source`, `importance`
- **Source**: 'areflect', 'reflection-cli', etc.

## Working Commands (11/11 ✅)

### Kernel Commands (from Nezha)
- ✅ `psypi task-add <title>` — Add task to DB
- ✅ `psypi tasks [--status <status>]` — List tasks from DB
- ✅ `psypi issue-add <title> [--severity <level>]` — Add issue to DB
- ✅ `psypi issues [--status <status>]` — List issues from DB
- ✅ `psypi skill-list` — List 624+ approved skills
- ✅ `psypi skill-show <name>` — Show skill details
- ✅ `psypi skill-build <name> <purpose>` — Build new skill

### Agent Commands (from NuPI)
- ✅ `psypi session-start` — Start session in DB
- ✅ `psypi session-end` — End session (set status='ended')

### All-in-One Commands
- ✅ `psypi areflect <text>` — Magic: [LEARN][ISSUE][TASK]
- ✅ `psypi context` — Show agent context from DB

## Known Issues & Fixes

### Bugs Found & Fixed During Integration:
1. **`agent_sessions` missing `ended_at` column** → Fixed `endSession()` to use `status='ended'`
2. **Import path errors** → Unified to use `.js` extensions
3. **Missing dependencies** (`uuid`, `nodemailer`, `handlebars`) → Installed
4. **TypeScript type errors** (`PiSDKExecutor.ts`) → Bypassed with `as any`
5. **nezha CLI `--help` handling errors** → Fixed in nezha (not psypi scope)

## Build & Git Info

### Build
- **Tool**: pnpm (fast builds)
- **Command**: `pnpm run build`
- **Output**: `dist/cli.js`
- **Hash**: Updated via `scripts/replace-hash.js`

### Git
- **Repo**: `~/gits/hub/tools_ai/psypi`
- **Branch**: master
- **Commits**: 3 (scaffolding, core commands, all working)
- **Status**: Ready to replace nezha/nupi

## Next Steps

1. **Global install**: `cd ~/gits/hub/tools_ai/psypi && npm install -g .`
2. **Test**: `psypi --help`
3. **Deprecate**: nezha and nupi once psypi is stable
4. **Integrate more**: `meeting`, `broadcast`, etc.

---

**Remember**: 
- ✅ **SESSION_ID** is the in-session identifier
- ✅ **areflect** is the all-in-one magic command
- ✅ **Database** is the source of truth
- ✅ **pnpm** builds faster

**Happy coding with psypi!** 🚀
