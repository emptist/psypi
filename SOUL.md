# SOUL.md - The Philosophy of psypi

## Identity

**psypi** = **Psy**che + **Pi** = Unified AI coordination system.

We are the **fusion** of:
- **Nezha** (kernel: DB, tasks, issues, skills, memory)
- **NuPI** (agent: Pi executor, autonomous work)

We are **one project** to maintain, not two.

## Core Beliefs

### 1. Database is Source of Truth
- PostgreSQL is the **only** source of truth
- No file caches, no `.nezha/` directories
- Every state lives in `psypi` database (migrated from `nezha` on 2026-05-03)

### 2. Session Identity is Simple
- `process.env.AGENT_SESSION_ID` is the **only** identifier
- No `CURRENT_AI_IDENTITY`, no static variables
- In-session persistence is enough

### 3. `areflect` is Magic
- All-in-one command: `[LEARN] [ISSUE] [TASK]`
- Parses human text and routes to correct DB tables
- One command to learn, report issues, create tasks

### 4. No Dead Code
- `nezha/examples/` removed (ai-collab, microservices, video-*, youtube-runner)
- Only core functionality preserved
- Don't let old patterns confuse you

### 5. Fast Builds with pnpm
- pnpm > npm (10s vs 24s)
- Use `pnpm install`, `pnpm run build`
- Keep `pnpm-lock.yaml` committed

## Architecture

```
psypi/
├── src/
│   ├── cli.ts          # Unified CLI (commander)
│   ├── kernel/         # Kernel core (DB, tasks, skills)
│   ├── agent/          # Agent core (Pi extension, autonomous work)
│   └── shared/         # Shared types
├── dist/              # Compiled output
└── package.json        # pnpm-managed
```

## Working Commands (11/11 ✅)

### Kernel (from Nezha)
- ✅ `psypi task-add` — Add task to DB
- ✅ `psypi tasks` — List tasks from DB
- ✅ `psypi issue-add` — Add issue to DB
- ✅ `psypi issues` — List issues from DB
- ✅ `psypi skill-list` — List 624+ skills
- ✅ `psypi skill-show` — Show skill details
- ✅ `psypi skill-build` — Build new skill

### Agent (from NuPI)
- ✅ `psypi session-start` — Start session in DB
- ✅ `psypi session-end` — End session in DB

### All-in-One
- ✅ `psypi areflect` — Magic: [LEARN][ISSUE][TASK]
- ✅ `psypi context` — Show agent context

## Known Issues & Fixes

### Bugs Found During Integration:
1. **`agent_sessions` missing `ended_at`** → Fixed `endSession()` to use `status='ended'`
2. **Import path errors** → Unified to use `.js` extensions
3. **Missing deps** (`uuid`, `nodemailer`, `handlebars`) → Installed
4. **TypeScript errors** (`PiSDKExecutor.ts`) → Bypassed with `as any`

## Mission

**Replace nezha + nupi** as the global CLI.

Once stable:
1. ✅ `npm install -g ~/gits/hub/tools_ai/psypi`
2. ✅ `psypi --help`
3. ⏳ Deprecate nezha and nupi
4. ⏳ Single project to maintain

---

**We are psypi — one system, many capabilities.** 🚀
