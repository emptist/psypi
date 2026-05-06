# BRIEF.md - psypi Project

## Vision
**psypi** = **Psyche + Pi** = Unified AI coordination system
- Replace both `nezha` and `nupi` as single CLI tool
- **Technically**: Pi TUI with extensions (not a traditional CLI!)
- Architecture: Gleam core + TypeScript bridge + Pi runtime

## Current State (2026-05-06)

### What Works ✅
- **Build**: `pnpm build` works (Gleam + TypeScript compilation)
- **33 CLI commands** with Pi tools (only 2 without: `provider-set-key`, `help`)
- **Gleam review**: `psypi commit` triggers Gleam `run_review()` (score: 70/100)
- **Database**: PostgreSQL shared across all projects
- **Pi Extension**: 17 tools using `ctx.ui.notify()` pattern

### Architecture Reality
```
psypi (command)
    ↓
bin/psypi.mjs (Node.js launcher)
    ↓
spawns 'pi' (Pi TUI) as child process
    ↓
Pi tools import Gleam-compiled JavaScript (.mjs files)
    ↓
JavaScript talks to PostgreSQL
```

### Code Stats
- **Gleam**: 380 lines (1.4%) - Core logic (review, session, CLI)
- **TypeScript**: 26,493 lines (98.6%) - Being migrated to Gleam
- **Ratio**: 1:70 (Gleam:TS) - Target: 1:5 by end of 2026

## Goal: Natural Gleam Migration

### Strategy (from docs/MIGRATION-TS-TO-GLEAM-2026.md)
**"Touch TS = Rewrite in Gleam"** - Natural growth, not big bang rewrite

### Why Gleam?
- **5-40x less code** for same functionality (see review.gleam: 12 lines vs TS: 500+)
- **Type safety** at development time
- **Small + Pure = Resilience** (all Gleam modules < 100 lines!)

### What to Migrate
1. **CLI commands** (currently duplicated in cli.ts AND kernel/cli/index.ts)
2. **Services** (heavy OOP, event emitters → simple pure functions)
3. **InterReviewService** (1,209 lines → target: ~30 lines in Gleam)
4. **DatabaseSkillLoader** (913 lines → target: ~100 lines)
5. **MeetingCommands** (619 lines → simpler state management)

## Success Criteria
- [ ] Gleam: 2,000+ lines (from current 380)
- [ ] TypeScript: 10,000- lines (from current 26,493)
- [ ] Ratio: 1:5 (Gleam:TS)
- [ ] All core commands in Gleam
- [ ] Real Pi agent (replace fake inner AI)

## Constraints
- **ONE database** per user home (shared across ALL projects)
- **Pi TUI integration** - psypi is a Pi extension, not standalone CLI
- **Never delete - deprecate** (use `.ts.deprecated` extension)
- **Use `psypi commit`** (mandatory Gleam review!)

## Next Steps
Create roadmap for natural Gleam migration with atomic, executable phases.
