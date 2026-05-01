# Psypi - Unified AI Coordination System

> **Psy**che + **Pi** = The unified AI coordination system  
> Replaces both `nezha` and `nupi` as the single CLI tool.

## Vision

- **Unified** codebase (no more maintaining two projects)
- **Simple** integration (no server, no strange things)
- **Kernel + Agent** in one package
- **Complete replacement** for `nezha` and `nupi` (which will be deleted once psypi is mature)

## 🎯 Architecture

```
psypi/
├── src/
│   ├── cli.ts          # Unified CLI (commander)
│   ├── kernel/         # Nezha core (DB, tasks, memory, skills)
│   ├── agent/          # NuPI core (Pi extension, autonomous work)
│   └── shared/         # Shared types/interfaces
├── dist/              # Compiled output
└── package.json        # pnpm-managed
```

## 📦 Installation (Global CLI)

### pnpm (Official & Recommended)

```bash
# Install globally using pnpm
cd ~/gits/hub/tools_ai/psypi
pnpm install --global-dir /Users/jk/Library/pnpm/global/5 -g .

# Test
psypi --version
psypi --help
```

**Note**: pnpm uses `--global-dir` + `-g` for global installs.

**Build time**: pnpm ~10s vs npm ~24s 🚀

## Commands (30+ Available, All Working ✅)

### ✅ Core Commands
- ✅ `psypi task-add <title>` — Add a task
- ✅ `psypi tasks [--status <status>]` — List tasks
- ✅ `psypi issue-add <title> [--severity <level>]` — Add an issue
- ✅ `psypi issue-list [--status <status>]` — List issues
- ✅ `psypi skill-list` — List all approved skills
- ✅ `psypi skill-show <name>` — Show skill details
- ✅ `psypi skill-build <name> <purpose>` — Build new skill
- ✅ `psypi areflect <text>` — Magic: [LEARN] [ISSUE] [TASK] parsing
- ✅ `psypi context` — Show current context
- ✅ `psypi session-start` — Start a new agent session
- ✅ `psypi session-end` — End current agent session

## 🛠 Current Status

### ✅ What Works Now (All Complete!):
- **Build**: ✅ Working (pnpm run build - no errors!)
- **All 30+ Commands**: ✅ Working and tested
- **Inner AI**: ✅ Working (with provider fallback)
- **Meeting System**: ✅ Complete (list, show, opinion, complete)
- **Autonomous Mode**: ✅ Working (`psypi autonomous`)
- **Think Delegation**: ✅ Working (`psypi think`)
- **Inter-Review**: ✅ Working (listReviews bug fixed!)
- **Documentation**: ✅ Updated (nezha/nupi references removed)

## Development

```bash
# Install dependencies (pnpm is faster!)
pnpm install

# Build (NOW WORKING! ✅)
pnpm run build

# Type check
pnpm run typecheck

# Development mode
pnpm run dev
```

## Migration Path

1. ✅ **Phase 1**: Scaffolding (done)
2. ✅ **Phase 2**: Integrate kernel (done)
3. ✅ **Phase 3**: Integrate agent (done - all commands working)
4. ✅ **Phase 4**: Replace nezha/nupi globally (done!)
5. 🚀 **Phase 5**: Deprecate nezha/nupi (they will be deleted once psypi is mature)

## Security

- ✅ **No secrets in files** (checked with grep)
- ✅ **Database is private**
- ✅ **`.env.example` only** (no real secrets)
- ✅ **`.env` not committed** (in `.gitignore`)

---

**Note**: `nezha` and `nupi` will be deleted once psypi is mature. Psypi is the complete, unified system.
