# Release Readiness Audit — 2026-06-07

## Summary

| Area | Status | Gap |
|------|--------|-----|
| **Tests** | ⚠️ 12% coverage | 0 integration tests, 43/49 modules untested |
| **CI/CD** | ❌ Missing | No GitHub Actions workflow |
| **Repo Hygiene** | ⚠️ Needs cleanup | Debug artifacts, orphan files, 72 unorganized docs |
| **Documentation** | ⚠️ Incomplete | No CONTRIBUTING.md, no CHANGELOG |
| **Security** | ✅ Good | Parameterized queries, no hardcoded secrets |
| **Dependencies** | ✅ Good | All pinned, no deprecated packages |
| **Build** | ✅ Good | Makefile + setup.sh exist |
| **License** | ✅ Done | MIT |

## Top 5 Blockers

### 1. No CI/CD

No GitHub Actions workflow. Anyone cloning gets zero build/test verification.

### 2. Test Coverage (12%)

Only code generation + prompt building tested. All 18 Pi tools, 6 hooks, 5 DB modules have 0 tests.

| Area | Modules | Tested | Coverage |
|------|---------|--------|----------|
| Code Generation | 3 | 3 | 100% |
| Prompt Building | 2 | 2 | 100% |
| Identity Types | 1 | 1 | 100% |
| Pi Tools (agent-facing) | 18 | 0 | 0% |
| Database Layer | 5 | 0 | 0% |
| Hooks (runtime) | 6 | 0 | 0% |
| Agent Identity (runtime) | 3 | 0 | 0% |
| System Review | 4 | 0 | 0% |
| Config / Utils | 3 | 0 | 0% |

No `make test` target exists. No test database infrastructure.

### 3. Repo Hygiene

Debug artifacts tracked in git:
- `extension_test.js` — test copy of extension.js
- `fix_agent_end.py` — Python debugging script
- `ppitest*.mjs` — debug files (in .gitignore but tracked)
- `CURRENT-STATE.md`, `REFACTOR-NOTES.md`, `SESSION-SUMMARY-*.md`, `HANDOVER.md` — session artifacts
- `migration-plan.txt` — planning artifact
- `.planning/` directory — planning docs

Orphan/duplicate files in src/:
- `src/time_utils_ffi.mjs` — orphan file (Bug #10), nothing imports it
- `agent_identity_ffi.mjs` duplicates 4 functions from `pi_extension_ffi.mjs` (Bug #12)

### 4. Missing Files

- No `CONTRIBUTING.md` — no guidance for contributors
- No `CHANGELOG.md` — no history of changes
- `gleam.toml` has empty `repository` field
- `.env.example` has misleading API key placeholders (project uses Pi's model API, not direct OpenAI/OpenRouter keys)

### 5. Documentation Overload

72 files in `docs/`. Many are dated session summaries, investigation reports, and reviews that are historical. No index or navigation guide for newcomers. Several reference removed modules (`a_orchestrator.gleam`).

## What's Already Good

- **Security**: All 80+ DB queries use parameterized queries. No hardcoded secrets. `.env` gitignored.
- **Dependencies**: All 8 runtime deps + 1 dev dep pinned to SemVer ranges. No deprecated packages.
- **Error handling**: Remarkably clean — 1 TODO, 0 FIXME/HACK/XXX in entire codebase.
- **Known issues**: 14 historical bugs all documented as fixed.
- **Build**: Makefile with 8 targets + comprehensive `bin/setup.sh` (165 lines).
- **Tests quality**: All 108 test functions have real assertions (no smoke tests). Excellent edge-case coverage where tests exist.

## Detailed Findings

### Tests

**6 test files, 108 test functions:**
- `pi_tool_call_test.gleam` — 42 tests (JS code generation)
- `a_prompt_builder_test.gleam` — 28 tests (prompt composition)
- `system_prompt_types_test.gleam` — 15 tests (budget/priority logic)
- `extension_generator_test.gleam` — 15 tests (extension.js output)
- `a_context_utils_test.gleam` — 5 tests (JSON parsing)
- `psypi_test.gleam` — 3 tests (identity type string format)

**Zero test helpers, zero shared fixtures, zero mock DB utilities.**

### Build/Release

- Makefile targets: setup, build, migrate, seed, start, minimal, clean, help
- No `test` target
- No CI/CD pipeline
- No release script or version bump automation

### Configuration

- Database: `PSYPI_DATABASE_NAME` (default: `psypi`), `POSTGRESQL_PORT` (default: 5432)
- Auth: trust (local dev appropriate)
- Runtime config: `psypi_config` table (monitor_debounce_ms, idle_since, etc.)
- `.env.example` documents env vars but may be misleading about API key usage

### Migrations

- 91 migration files (003 through 049 with sub-variants)
- 36 sub-lettered migrations (027a-027z, 028a-028i, 029a-029j) are audit/verification clutter
- Migration 005 creates deprecated `system_directives` table
- Migration 025 drops it — ordering confusing on fresh installs
