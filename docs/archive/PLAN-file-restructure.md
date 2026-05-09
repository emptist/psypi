# PLAN: File Structure Cleanup

## Status
- **Created**: 2026-05-08
- **Priority**: Low — cosmetic/organizational, no code changes
- **Safe to execute now** — the extension bug has been fixed (2026-05-08)

---

## Goal

Reduce root clutter from ~61 items → ~15 items. Make the project scannable at a glance.

---

## Current State

### Root (`/`) — ~61 items, mixing concerns

**Belongs in root (keep):**
- `AGENTS.md` — agent instructions
- `README.md` — project overview
- `bin/` — entry point
- `gleam/` — Gleam source
- `src/` — JS bridge / generated extension
- `docs/` — documentation
- `deprecated/` — deprecated TS files
- `scripts/` — active scripts
- `hooks/` — git hooks
- `.pi/` — Pi skills/prompts
- `node_modules/` — runtime deps

**Does NOT belong in root (move):**
- 10 `test-*` files → `tests/`
- `package.json.backup`, `package.json.deprecated` → `deprecated/`
- ~17 loose `.md` files → categorized (see below)

### `docs/` — 44+ files, mixing living docs with one-time reports

**Living docs (keep in `docs/`):**
- `ADDING_SKILLS_GUIDE.md`
- `AGENT_IDENTITY_TRACKING_DESIGN.md`
- `CLI_TO_PI_TOOL_MIGRATION.md`
- `cli-vs-pi-tools.md`
- `DEVELOPER_GUIDE_ACTIVITY_TRACKING.md`
- `GLEAM-MIGRATION-STRATEGY.md`

**One-time reports/reviews → `docs/archive/`:**
- `BUG-extension-pi-not-defined.md` (bug is fixed, this is historical)
- `BUGFIX-2026-05-07.md`
- `CODE_REVIEW_2026-05-04.md`, `CODE_REVIEW_2026-05-04_v2.md`, `CODE_REVIEW.md`
- `GLEAM-CODE-REVIEW-2026-05-08.md`
- `DISASTER-REPORT-2026-05-06.md`
- `INVESTIGATION-REPORT-2026-05-07.md`
- `TOOL_AUDIT-2026-05-07.md`
- `SKILLS_INTEGRATION-2026-05-07.md`
- `REPAIR-PLAN.md`, `REPAIR-PRE-DISCUSSION-NOTES.md`
- `HANDOVER-2026-05-07-FINAL.md`, `HANDOVER-2026-05-07.md`
- `PLAN-file-restructure.md` — this file stays in `docs/` (or move to root)

**Old plans (superseded) → `docs/archive/`:**
- `MIGRATION_PLAN.md`, `MIGRATION-TS-TO-GLEAM-2026.md`
- `PLAN-gleam-migration-2026-05-05.md`
- `PI_AGENT_IMPLEMENTATION_PLAN.md` (41KB!)
- `CORRECT-WORKFLOW-ADD-TOOL.md`, `DEPRECATION-WORKFLOW.md`

**Reference/learning → `docs/archive/`:**
- `pi-answers.md` (29KB, raw research notes)
- `pi-session-id-truth.md` (superseded by code)
- `PNPM_USAGE.md` (trivial, in AGENTS.md already)
- `SUPER-SIMPLE-GUIDE-FOR-DUMMY-AI.md`
- `XIAOHONGSHU-Gleam-vs-TypeScript.md`
- `AUTO_BACKUP_HOOK.md`, `BACKUP-STRATEGIES.md`
- `PROJECT_CONTEXT.md`
- `Principles4RepairPlanByHuman.md`
- `IDEA-database-first-skills.md`
- `REAL-MONITOR-PARTNER-AI.md`
- `AI_GUIDE-requesting-pi-extensions.md`
- `HOW_TO_JOIN_MEETING_*.md` (already in archive/)

**Keep in `docs/`:**
- `BOOK-What-I-Wish-I-Knew-When-Starting-Pi.md` (useful reference)
- `ADDING_SKILLS_GUIDE.md` (how-to guide)

---

## Target Structure

```
psypi/
│
├── bin/                          # Entry point
├── gleam/                        # Gleam source
├── src/
│   ├── agent/extension/          # extension.js (generated)
│   └── kernel/                   # Core JS utilities
├── docs/
│   ├── architecture/             # Design docs (stable reference)
│   │   ├── AGENT_IDENTITY_TRACKING_DESIGN.md
│   │   ├── CLI_TO_PI_TOOL_MIGRATION.md
│   │   ├── cli-vs-pi-tools.md
│   │   ├── DEVELOPER_GUIDE_ACTIVITY_TRACKING.md
│   │   └── GLEAM-MIGRATION-STRATEGY.md
│   ├── guides/                   # How-to guides
│   │   ├── ADDING_SKILLS_GUIDE.md
│   │   └── BOOK-What-I-Wish-I-Knew-When-Starting-Pi.md
│   └── archive/                  # One-time reports, old plans, research
│       └── (all historical docs)
├── tests/                        # All test files (new)
│   ├── test-bridge.mjs
│   ├── test-extension.js
│   ├── test-final.mjs
│   ├── test-full-chain.mjs
│   ├── test-full-integration.mjs
│   ├── test-gleam-call.mjs
│   ├── test-god-awakens.mjs
│   ├── test-integration.mjs
│   ├── test-pi-sdk.mjs
│   └── test-simple.mjs
├── deprecated/                   # All deprecated files
│   ├── (existing .ts.deprecated files)
│   ├── package.json.backup
│   └── package.json.deprecated
├── scripts/
│   ├── fix-imports.mjs
│   ├── fix-shebang.cjs
│   └── deprecated/
├── hooks/
├── .pi/
│
├── AGENTS.md
└── README.md
```

---

## Migration Steps (execute in order)

### Phase 1: Create new directories
```bash
mkdir -p docs/architecture docs/guides tests
```

### Phase 2: Move test files
```bash
mv test-bridge.mjs tests/
mv test-extension.js tests/
mv test-final.mjs tests/
mv test-full-chain.mjs tests/
mv test-full-integration.mjs tests/
mv test-gleam-call.mjs tests/
mv test-god-awakens.mjs tests/
mv test-integration.mjs tests/
mv test-pi-sdk.mjs tests/
mv test-simple.mjs tests/
mv test-gleam-executable tests/
```

### Phase 3: Move deprecated package.json files
```bash
mv package.json.backup deprecated/
mv package.json.deprecated deprecated/
```

### Phase 4: Categorize root .md files

**Personal notes → ask user before removing:**
- `SOUL.md`, `MEMORY.md`, `MEMO-2026-05-05.md`

**Stale issue tracking → deprecated/:**
- `OPEN_ISSUES.md`, `REMAINING_ISSUES.md`, `PSYPI_ISSUES.md`

**Old reviews/reports → docs/archive/:**
- `REVIEW.md`, `DEEP_REVIEW.md`, `STRATEGIC_ANALYSIS.md`
- `HANDOVER-2026-05-05.md`, `HANDOVER-2026-05-08.md`
- `COMMANDS.md`, `DATABASE_CONFIG.md`, `DATABASE_MIGRATION_REPORT.md`
- `INNER_AI_TO_PI_AGENT-COMPLETE-FEATURE.md`, `TRAENUPI_COMPARISON.md`
- `cli-pi-tool-status.md`, `test-agents-md.md`, `test-commit.md`, `test-db-docs.md`

### Phase 5: Categorize docs/ files

**To docs/architecture/:**
- `AGENT_IDENTITY_TRACKING_DESIGN.md`
- `CLI_TO_PI_TOOL_MIGRATION.md`
- `cli-vs-pi-tools.md`
- `DEVELOPER_GUIDE_ACTIVITY_TRACKING.md`
- `GLEAM-MIGRATION-STRATEGY.md`

**To docs/guides/:**
- `ADDING_SKILLS_GUIDE.md`
- `BOOK-What-I-Wish-I-Knew-When-Starting-Pi.md`
- `AI_GUIDE-requesting-pi-extensions.md`

**To docs/archive/:**
- All one-time reports, old plans, code reviews, research notes

### Phase 6: Clean up root test .md files
```bash
# These are test artifacts, not real docs
mv test-agents-md.md deprecated/
mv test-commit.md deprecated/
mv test-db-docs.md deprecated/
```

---

## What Stays in Root

| Item | Why |
|------|-----|
| `AGENTS.md` | Agent instructions (required by Pi) |
| `README.md` | Project overview |
| `bin/` | Entry point |
| `gleam/` | Gleam source |
| `src/` | JS bridge |
| `docs/` | Documentation |
| `tests/` | Test files |
| `deprecated/` | Deprecated code |
| `scripts/` | Active scripts |
| `hooks/` | Git hooks |
| `.pi/` | Pi skills/prompts |
| `node_modules/` | Runtime deps |

**Total: 11 items (down from ~61)**

---

## Warnings

- **DO NOT move `AGENTS.md`** — Pi expects it in project root
- **DO NOT move `.pi/`** — Pi auto-discovers from project root
- **Check for broken references** — some docs may reference others by relative path
- **Personal files** (`SOUL.md`, `MEMORY.md`, `MEMO-2026-05-05.md`) — ask user before removing
- **Nothing is deleted** — only moved/organized

---

## Result

A clean, scannable project structure where root shows only essential project files, docs are categorized, tests live in `tests/`, and nothing is deleted.
