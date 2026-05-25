# RELEASE PLAN — psypi v1.0.0

**Status:** DRAFT  
**Last updated:** 2026-05-24  
**Goal:** First user-ready release — a fresh clone → `make setup` → working psypi instance.

---

## 1. Scope

### In Scope
- **Dual-worker architecture**: S-bot (somatic, prompt-driven) + A-bot (autonomic, event-driven)
- **Gleam core modules**: Type-safe business logic compiled to JS via `gleam build`
- **30+ Pi tools**: task, issue, skill, meeting, memory, broadcast, commit, doc versioning
- **Event hook system**: 10 hooks (tool_call, tool_result, before_agent_start, agent_end, etc.)
- **One-command setup**: `make setup` / `bin/setup.sh` handles deps, DB, build, migrate, seed
- **Seed data**: agent souls, config, prefixes, 3 local skills (psypi-basics, psypi-dev, getting-started)
- **Inter-review commit flow**: A-bot reviews before S-bot commits
- **Meeting system**: Multi-agent opinions, consensus, short-ID resolution
- **Auto-backup**: File versioning before AI edits
- **Autonomic wake-up**: A-bot sends wake-up messages to S-bot after idle debounce

### Out of Scope
- Web UI / dashboard
- Plugin marketplace / ClawHub integration
- Multi-project support (single project_id per deployment)
- Full A↔S bidirectional communication (DB-backed reply channel)
- Advanced monitoring UI
- Docker setup

---

## 2. Release Checklist

### 2.1 Setup & Onboarding (from `PLAN-first-user-release.md`)

| # | Item | Status |
|---|------|--------|
| 1 | Fix `config.gleam` get_env stub | ✅ FFI binding wired to `node_ffi.mjs` |
| 2 | Fix `psypi_config` vs `system_config` naming | ✅ MONITOR-DEBOUNCE.md corrected |
| 3 | Create `seed.gleam` module | ✅ 99 lines, idempotent |
| 4 | Create `getting-started` skill | ✅ Complete with 5-min walkthrough |
| 5 | Create `bin/setup.sh` | ✅ 165 lines, all 11 steps |
| 6 | Create `Makefile` | ✅ 8 targets |
| 7 | Rewrite `README.md` | ✅ 105 lines, new-user focused |
| 8 | Fix `MONITOR-DEBOUNCE.md` | ✅ Accurate table name and defaults |
| 9 | Complete `table_documentation` | ⚠️ Missing — no dedicated docs for 7 tables |

### 2.2 Code Quality (open issues to resolve before release)

| ID | Issue | Severity | Effort |
|----|-------|----------|--------|
| `c2b04162` | `hook_on_agent_end.gleam` parse_context_window uses fragile string splitting instead of JSON decoder | Medium | Small |
| `b6f2d90c` | `identity.gleam` is redundant with `agent_identity.gleam` | Medium | Small |
| `2e8b4a82` | Duplicate `db_error_to_*` error mapper functions across 22 modules | Medium | Medium |
| `2e49cd52` | Duplicate `decode_all_results` pattern across 6+ modules | Medium | Medium |

### 2.3 Known Blockers & Risks

| Risk | Severity | Status |
|------|----------|--------|
| Hooks not firing (trigger_count=0) | High | Investigated — diagnostics added, needs Pi restart to verify |
| `psypi-issue-count` returns 0 | Medium | Known bug, doesn't block release |
| `system_config.gleam` naming confusion | Low | Works but module name is misleading |
| 4 open code quality issues | Low | Non-blocking, can be fixed post-release |

---

## 3. Milestones

### Milestone 1: Setup Complete ✅
- `bin/setup.sh` runs end-to-end
- `make setup` works from fresh clone
- Seed data populates correctly
- README.md has clear getting-started

### Milestone 2: Core Tools Verified ✅
- `psypi-my-id` returns correct identity
- `psypi-tasks` lists tasks without decode errors
- `psypi-skill-list` shows skills
- `psypi-stats-show` works
- `psypi-commit` delegates review to A-bot

### Milestone 3: Code Quality ⏳
- Fix 4 remaining open code quality issues
- Build passes with zero new warnings
- No hardcoded values in source

### Milestone 4: Documentation ⏳
- Table documentation for 7 DB tables
- Architecture docs updated
- CHANGELOG.md for v1.0.0

### Milestone 5: Release 🎯
- Git tag `v1.0.0`
- All checklist items verified
- Fresh-clone test passes

---

## 4. Database Tables

| Table | Purpose | Documented |
|-------|---------|------------|
| `psypi_config` | Key-value config (debounce, last_wakeup) | ✅ MONITOR-DEBOUNCE.md |
| `agent_identities` | Agent identity snapshots | ⚠️ |
| `agent_souls` | Agent self-knowledge and role | ⚠️ |
| `agent_tasks` | Prioritized work items per agent | ⚠️ |
| `agent_prefixes` | A, S, G prefix definitions | ⚠️ |
| `system_directives` | Autonomic → Somatic directives | ⚠️ |
| `psypi_event_hooks` | Hook registration and status | ⚠️ |
| `tasks` | Task management (psypi-task-*) | ⚠️ |
| `code_versions` | File version history | ⚠️ |
| `issues` | Issue tracking | ⚠️ |
| `skills` | Skill registry | ⚠️ |
| `meetings` | Multi-agent meeting records | ⚠️ |

---

## 5. Verification (End-to-End Test)

From a fresh clone:
```bash
# 1. Prerequisites
node --version  # ≥ 18
gleam --version # ≥ 1.16
pi --version    # exists
pg_isready      # accepting

# 2. Setup
make setup      # or: bash bin/setup.sh

# 3. Start
node bin/ppi.mjs

# 4. Inside Pi TUI:
/psypi-my-id                              → S-psypi-...
/psypi-tasks                              → lists tasks (empty ok)
/psypi-skill-list                         → lists skills
/psypi-skill-search query="getting-started" → finds it
/psypi-stats-show                         → works
/psypi-issue-count                        → works (known: returns total not filtered)
/psypi-commit message="test"              → triggers A-bot review
```

---

## 6. Open Questions

1. **Hook firing verification**: Has the trigger_count=0 issue been resolved? Needs Pi restart + observation.
2. **A-bot wake-up reliability**: Does `pi_send_message` with `triggerTurn: true` actually deliver? Untested end-to-end.
3. **Release tagging**: Who creates the `v1.0.0` git tag and when?

---

*This plan complements `PLAN-first-user-release.md` (setup/onboarding tasks). This file focuses on release scope, blockers, and milestones.*
