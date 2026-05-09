# Psypi Project Review — 2026-05-01

> Reviewed by Trae AI agent (S-TRAE-psypi session) using codebase analysis + traenupi

## Project Overview

**Psypi** (`Psy`che + `Pi`) is a unified AI coordination system merging **Nezha** (kernel: DB, tasks, issues, skills, memory) and **NuPI** (agent: Pi executor, autonomous work) into a single CLI tool.

- **Language**: TypeScript (ES2022, Node16 modules)
- **Runtime**: Node.js >= 18
- **Database**: PostgreSQL (Nezha DB)
- **Package Manager**: pnpm
- **Pi Integration**: `@mariozechner/pi-coding-agent`

---

## Build Status

**2 TypeScript errors** from a single typo:

| File | Line | Error |
|------|------|-------|
| `src/kernel/config/Config.ts` | 25 | `import * as os from .os.` — should be `import * as os from 'os'` |

This is the **only** build blocker. The README mentions 4 errors, but the other 3 have been resolved:
- `downlevelIteration` already set in `tsconfig.json`
- `kernel` export exists in `src/kernel/index.ts`
- `AgentIdentityService.ts` now uses `import crypto from 'node:crypto'` correctly

---

## Issues Reported to DB (8 total)

| # | Severity | Issue | DB ID |
|---|----------|-------|-------|
| 1 | 🔴 Critical | Config.ts:25 typo `.os.` → `'os'` — only build-blocking error | `71f4ddf4` |
| 2 | 🟠 High | Dual database access layers (Kernel Pool vs extension db.ts) | `9016e1b6` |
| 3 | 🟠 High | Empty agent module (src/agent/index.ts = 0 lines) | `9c02c800` |
| 4 | 🟠 High | SQL injection in DatabaseClient.ts:42 (string interpolation in SET app.git_branch) | `61b48b92` |
| 5 | 🟠 High | Kernel hardcodes `created_by: 'psypi'` instead of resolved agent identity | `41993cd1` |
| 6 | 🟡 Medium | Two parallel CLI entry points (cli.ts vs kernel/cli/index.ts) | `1058eb10` |
| 7 | 🟡 Medium | No tests (0% coverage on 60+ files, 74 migrations) | `40aec9da` |
| 8 | 🟢 Low | .gitignore missing .tmp/, .trae/, coverage/ | `54a2e64e` |

---

## Architecture Analysis

### Dual Database Access (Major Inconsistency)

Two completely separate database access layers that share no code:

| Layer | File | Pattern | Config Source | Error Handling |
|-------|------|---------|---------------|----------------|
| Kernel | `src/kernel/db/DatabaseClient.ts` | Class-based, `IConfig` interface | `Config.getInstance()` | Throws after logging |
| Agent Extension | `src/agent/extension/db.ts` | Module-level singleton, raw `Pool` | `NUPI_DB_*` env vars | Silently swallows (returns `[]`/`null`) |

Problems:
- Different env var prefixes (`NEZHA_DB_*` vs `NUPI_DB_*`) for the **same database**
- No shared connection pooling
- No shared query logging
- Extension's `querySafe()` silently swallows errors

### Kernel God Object

`src/kernel/index.ts` (405 lines) is a monolithic class that:
- Manages its own `Pool` connection (ignoring `DatabaseClient`)
- Contains all CRUD operations inline (tasks, issues, skills, sessions)
- Has `any` typed service references (`interReviewService: any`, `broadcastService: any`)
- Duplicates logic that exists in the service layer (e.g., `TaskCommands`, `IssueCommands`)
- Hardcodes `created_by: 'psypi'` in all INSERT statements

### Two CLI Entry Points

| Entry Point | Architecture | Status |
|-------------|-------------|--------|
| `src/cli.ts` | Commander-based, uses `Kernel` singleton | Registered in `package.json` bin |
| `src/kernel/cli/index.ts` | Raw `process.argv` parsing, uses `DatabaseClient` + services | Not registered in bin |

The `kernel/cli/index.ts` (1066 lines) has more complete functionality (meeting commands, inner AI, agents) but is unreachable from the installed binary.

### Empty Agent Module

`src/agent/index.ts` is **0 lines** — the NuPI integration is disconnected from the kernel. The extension code exists in `src/agent/extension/extension.ts` (1225 lines) but nothing wires it together.

---

## Security Findings

### SQL Injection Risk — DatabaseClient.ts:42

```typescript
// CURRENT (vulnerable):
await client.query(`SET app.git_branch = '${branch}'`);

// SHOULD BE:
await client.query(`SET app.git_branch = $1`, [branch]);
```

### .gitignore Incomplete

Missing entries that the project actually uses:
- `.tmp/` — logger writes to `.tmp/logs/` by default
- `.trae/` — Trae skill sync directory
- `coverage/` — test coverage output

### .env.example Default Credentials

```
DB_PASSWORD=postgres
```

While marked as example, this encourages using default credentials.

---

## Code Quality Issues

### Pervasive `any` Usage

- `Kernel`: `interReviewService: any`, `broadcastService: any`, `params: any[]`
- `PiSDKExecutor`: `as any` bypasses for Pi SDK types
- `extension.ts`: `params: any` in multiple tool execute functions
- `db.ts`: `any[]` and `Record<string, any>` everywhere

### No Tests

```json
"test": "echo 'Tests coming soon' && exit 0"
```

0% coverage on 60+ source files and 74 database migrations.

### Error Handling Inconsistency

- `Kernel` methods: try/catch with `console.error`
- `DatabaseClient`: throws errors after logging
- Agent extension `db.ts`: silently swallows errors
- Services: mixed patterns (some throw, some return null, some log and continue)

---

## Strengths

1. **Comprehensive migration system** — 74 well-organized migration files with descriptive names and proper SQL
2. **Rich type definitions** — `src/kernel/config/types.ts` has thorough interfaces for all domain objects
3. **Well-structured constants** — `src/kernel/config/constants.ts` uses `as const` and `satisfies` for type safety
4. **Trae integration** — `TraeAutoRecoveryService` and `TraeSkillSyncService` are well-designed with proper config, logging, and error handling
5. **Agent identity system** — `AgentIdentityService` has semantic ID generation (S-/I-/G- prefixes), Trae detection, and machine fingerprinting
6. **Pi SDK integration** — `PiSDKExecutor` properly handles timeouts and streaming events
7. **Logger** — `src/kernel/utils/logger.ts` has file rotation, JSON output, and child loggers
8. **Config system** — Singleton pattern with YAML + env var loading, validation, and health checks

---

## Project Metrics

| Metric | Value |
|--------|-------|
| TypeScript source files | ~60+ |
| Database migrations | 74 |
| Service files | 45+ |
| CLI commands (working) | 11 |
| CLI commands (added, untested) | 12 |
| CLI commands (missing) | 14+ |
| Build errors | 2 (from 1 line) |
| Test coverage | 0% |
| `any` type usage | Pervasive |

---

## traenupi Session Findings

Running `traenupi start` revealed:

- **50 knowledge entries** loaded from Nezha DB
- **5 pending inter-reviews** — all from `S-TRAE-nezha-2026042*`, awaiting processing
- **Baby AI identified** unresolved critical issues: Trae session ID detection gaps, AgentIdentityService missing Trae support, and unknown critical issues from 2026-04-21

---

## Recommended Priority Actions

### Phase 1: Fix Build (5 minutes)
1. Fix `Config.ts:25`: change `import * as os from .os.` → `import * as os from 'os'`
2. Verify build with `pnpm run typecheck`

### Phase 2: Security (30 minutes)
1. Fix SQL injection in `DatabaseClient.getGitBranch()` — use parameterized query
2. Update `.gitignore` — add `.tmp/`, `.trae/`, `coverage/`

### Phase 3: Architecture Consolidation (1-2 days)
1. Unify database access — remove Kernel's direct Pool usage, route through DatabaseClient
2. Merge CLI entry points — choose Commander-based `cli.ts` and port missing commands
3. Wire up agent module — create `src/agent/index.ts` to connect extension to kernel
4. Fix `created_by` hardcoding — use AgentIdentityService for attribution

### Phase 4: Quality (ongoing)
1. Remove `any` types — start with service interfaces and Kernel class
2. Add basic tests — Kernel CRUD operations and Config loading
3. Implement missing commands from COMMANDS.md

---

## Core Insight

> Psypi suffers from **integration debt**: the Nezha kernel and NuPI agent were merged structurally but not architecturally. The dual database layers, dual CLI entry points, and disconnected agent module are the clearest evidence of this. The single most impactful fix is the one-character typo in Config.ts:25 — fixing `.os.` to `'os'` will unblock the entire build and allow testing of all 12 "added but untested" commands.
