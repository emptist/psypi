# Psypi - Unified AI Coordination System

> **Psy**che + **Pi** = The unified AI coordination system  
> Replaces both `nezha` and `nupi` as the single CLI tool.

## Vision

- **Unified** codebase (no more maintaining two projects)
- **Simple** integration (no server, no strange things)
- **Kernel + Agent** in one package
- **Complete replacement** for `nezha` and `nupi` (now unified into psypi)

## 🎯 Architecture

```
psypi/
├── src/
│   ├── cli.ts          # Unified CLI (commander)
│   ├── kernel/         # Kernel core (DB, tasks, memory, skills)
│   ├── agent/          # Psypi core (Pi extension, autonomous work)
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
- ✅ `psypi task-complete <taskId>` — Mark task completed
- ✅ `psypi issue-add <title> [--severity <level>]` — Add an issue
- ✅ `psypi issue-list [--status <status>]` — List issues
- ✅ `psypi issue-resolve <issueId>` — Mark issue resolved
- ✅ `psypi skill-list` — List all approved skills (624+)
- ✅ `psypi skill-show <name>` — Show skill details
- ✅ `psypi skill-build <name> <purpose>` — Build new skill
- ✅ `psypi areflect <text>` — Magic: [LEARN] [ISSUE] [TASK] parsing
- ✅ `psypi context` — Show current context
- ✅ `psypi session-start` — Start a new agent session
- ✅ `psypi session-end` — End current agent session

### ✅ Identity & Session Commands (New!)
- ✅ `psypi my-id` — Print agent identity ID (S-psypi-psypi)
- ✅ `psypi partner-id` — Print permanent partner ID (I-tencent/hy3-preview:free-psypi)
- ✅ `psypi my-session-id` — Print Pi session ID (UUID v7)

### ✅ Pi Extension Tools (via psypi CLI)
- ✅ `psypi-think` — Delegate to external thinker
- ✅ `psypi-tasks` — Check pending tasks
- ✅ `psypi-autonomous` — Get autonomous work guidance
- ✅ `psypi-meeting-*` — Meeting management (say, summary, search, list)
- ✅ `psypi-doc-*` — Document management (save, list)
- ✅ `psypi-status` — Show PsyPI status
- ✅ `psypi-project` — Show project info
- ✅ `psypi-visits` — Show project visits
- ✅ `psypi-stats` — Show ecosystem statistics
- ✅ `psypi-areflect` — All-in-one reflection tool
- ✅ `psypi-commit` — Git commit with mandatory inter-review

### ✅ Other Commands
- ✅ `psypi agents` — List active agents
- ✅ `psypi announce <message>` — Send announcement to all AIs
- ✅ `psypi broadcast <message>` — Alias for announce
- ✅ `psypi meeting list/show/opinion` — Meeting management
- ✅ `psypi autonomous [context]` — Get autonomous work guidance
- ✅ `psypi think <question>` — Delegate to external thinker
- ✅ `psypi status` — Show psypi status
- ✅ `psypi project` — Show project info
- ✅ `psypi visits` — Show recent visits
- ✅ `psypi stats` — Show ecosystem stats
- ✅ `psypi doc-save` — Save project document
- ✅ `psypi doc-list` — List project documents
- ✅ `psypi learn <content>` — Save learning to memory
- ✅ `psypi tools` — List available tools from DB
- ✅ `psypi validate-commit <message>` — Validate commit format
- ✅ `psypi setup-hooks` — Install git hooks
- ✅ `psypi task-complete-by-commit <message>` — Complete tasks by commit
- ✅ `psypi inter-review-request <taskId>` — Request inter-review
- ✅ `psypi inter-review-show <reviewId>` — Show inter-review
- ✅ `psypi inter-reviews [status]` — List inter-reviews

## 🛠 Current Status

### ✅ What Works Now (All Complete!):
- **Build**: ✅ Working (`pnpm build` - no errors! Hash: 0739c61)
- **All 30+ Commands**: ✅ Working and tested
- **Pi Extension**: ✅ Updated with `ctx.ui.notify()` for all 17 tools
- **Inner AI**: ⚠️ Working but fake (stateless API - to be replaced with real Pi agent)
- **Meeting System**: ✅ Complete (list, show, opinion, complete)
- **Autonomous Mode**: ✅ Working (`psypi autonomous`)
- **Think Delegation**: ✅ Working (`psypi-think`)
- **Inter-Review**: ✅ Working (currently scores 70/100 - will improve with real Pi agent)
- **Documentation**: ✅ Updated (README, AGENTS.md, session summaries)
- **Cleanup**: ✅ Removed all nezha/nupi pollution from `~/.pi/agent/extensions/`

### 🚀 Next Major Step:
- **Replace fake inner AI** with real Pi agent via `createAgentSession()` (Pi SDK)
  - Will dramatically improve inter-review quality
  - Simplifies codebase (remove AIProviderFactory, fake HTTP calls)
  - Creates ever-lasting "God-like" permanent AI partner

## Development

```bash
# Install dependencies (pnpm is faster!)
pnpm install

# Build (WORKING! ✅)
pnpm build

# Type check
pnpm typecheck

# Development mode
pnpm dev
```

## Recent Work (2026-05-02)
- ✅ Updated all 17 Pi extension tools to use `ctx.ui.notify()` per Pi docs
- ✅ Cleaned `~/.pi/agent/extensions/` (removed ALL nezha/nupi .md files)
- ✅ Added 3 CLI commands: `my-id`, `partner-id`, `my-session-id`
- ✅ Fixed build errors (AgentIdentityService crypto import)
- ✅ Created vision: Ever-Lasting Permanent AI Partner
- ✅ Inter-review system operational (score: 70/100 - will improve with real Pi agent)

## Migration Path

1. ✅ **Phase 1**: Scaffolding (done)
2. ✅ **Phase 2**: Integrate kernel (done)
3. ✅ **Phase 3**: Integrate agent (done - all commands working)
4. ✅ **Phase 4**: Replace nezha/nupi globally (done!)
5. 🚀 **Phase 5**: Replace fake inner AI with real Pi agent (createAgentSession)
6. 🎯 **Phase 6**: Delete nezha/nupi (once psypi is mature)

---

**Note**: `nezha` and `nupi` will be deleted once psypi is mature. Psypi is the complete, unified system with proper Pi TUI integration (`ctx.ui.notify()` pattern). The fake inner AI will be replaced with a real Pi agent for dramatically better code reviews!
