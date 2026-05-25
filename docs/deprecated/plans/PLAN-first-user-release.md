# PLAN: First User-Ready Release

> **Goal:** A fresh user clones the repo, runs one command, and has a working psypi instance.
> **Scope:** Setup automation, critical bug fixes, seed data, documentation.
> **Out of scope:** Gleam migration, new features, A-bot improvements.

---

## Prerequisites (what the user must install)

These are **not** handled by setup — user installs them first:

| Tool | Install command | Verify |
|------|----------------|--------|
| Node.js 18+ | `brew install node` or https://nodejs.org | `node --version` |
| Gleam 1.16+ | `brew install gleam` or https://gleam.run | `gleam --version` |
| Pi | `npm install -g @earendil-works/pi-coding-agent` | `pi --version` |
| PostgreSQL 14+ | `brew install postgresql@18` or https://postgresql.org | `pg_isready` |

**Installation help strings (shown by setup.sh if missing):**
```
❌ Node.js not found → "Install from https://nodejs.org or: brew install node"
❌ Gleam not found   → "Install from https://gleam.run/getting-started/ or: brew install gleam"
❌ Pi not found       → "Run: npm install -g @earendil-works/pi-coding-agent"
❌ PostgreSQL down    → "Install from https://postgresql.org/download/ or: brew install postgresql@18"
                       "Then: brew services start postgresql@18"
```

---

## Work Items (ordered by dependency)

### 1. Fix `config.gleam` get_env stub
**File:** `src/config.gleam`
**Problem:** `get_env` always returns `""`, making `get_config()` always fail with `MissingEnv`.
**Fix:** Replace stub with `@external(javascript, "./node_ffi.mjs", "get_env")` FFI binding. `node_ffi.mjs` already has a working `get_env`.

### 2. Fix `psypi-config` vs `system_config` naming confusion
**Problem:** Code uses `psypi_config` table, but docs (MONITOR-DEBOUNCE.md) and some migration files reference `system_config`. The `system_config` table exists in DB but `config_reader.gleam` and `system_config.gleam` write to `psypi_config`.
**Fix:** Pick `psypi_config` as the canonical name (it's where the code actually reads/writes). Update docs to match. Make `system_config` an alias or remove references to it.

### 3. Create `seed.gleam` module
**File:** `src/seed.gleam` (new)
**Purpose:** Populate required initial data for a fresh database.
**Seeds:**
- `agent_souls` — A and S souls (if table empty)
- `psypi_config.monitor_debounce_ms` = `300000` (5 min)
- `psypi_config.last_wakeup` = `""`
- `agent_prefixes` — A, S, G prefixes
- `system_config.monitor_debounce_ms` = `300000` (if system_config table used for fallback)
- 3 local skills: `psypi-basics`, `psypi-dev`, `getting-started`
**Must be idempotent** — safe to run multiple times.

### 4. Create `getting-started` skill
**File:** `ppi_skills/getting-started/SKILL.md` (new)
**Brand-new user's first-read:**
- What is psypi (2 sentences, non-technical)
- S-bot and A-bot simply explained
- First 5 minutes walkthrough
- Common patterns (wake-up messages, commit workflow, doc-save)
- Links to psypi-basics and docs/

### 5. Create `bin/setup.sh`
**File:** `bin/setup.sh` (new)
**One-command setup.** Steps:
1. Check 4 prerequisites (node, gleam, pi, pg_isready) → print install help if missing
2. Start PostgreSQL if not running (brew/services detection)
3. Create `psypi` database if not exists
4. Enable extensions: `pgcrypto`, `vector`
5. Copy `.env.example` → `.env` if not exists
6. `gleam deps download`
7. `rm -rf build/ && gleam build`
8. `gleam run -m simple_migrate`
9. `gleam run -m seed`
10. Regenerate `extension.js`
11. Print success + next steps

### 6. Create `Makefile`
**File:** `Makefile` (new)
**Targets:** `setup`, `build`, `migrate`, `seed`, `start`, `minimal`, `clean`, `help`

### 7. Rewrite `README.md`
**File:** `README.md` (rewrite)
**Audience:** Brand-new user who just cloned.
**Structure:**
- What is psypi (2 sentences)
- Quick start (3 commands)
- What you get (bullet list of features)
- Commands cheat sheet
- Dependencies
- Architecture (simple diagram)
- Configuration
- Troubleshooting
**Move old dev content to `docs/` or archive.**
**Target:** Under 150 lines.

### 8. Fix `MONITOR-DEBOUNCE.md`
**File:** `docs/MONITOR-DEBOUNCE.md`
**Fix:** Table name (`psypi_config` not `system_config`), accurate default (300000ms), correct doc.

### 9. Complete `table_documentation`
**Missing tables:** `psypi_config`, `agent_identities`, `agent_sessions`, `agent_tasks`, `agent_prefixes`, `system_directives`, `psypi_event_hooks`
**Add entries for each.**

---

## Dependency Graph

```
config.gleam fix ──→ seed.gleam ──→ setup.sh ──→ Makefile
                      │                              │
                      ├→ getting-started skill       │
                      └→ skills seeding              │
                                                     │
README.md rewrite ───────────────────────────────────┘
MONITOR-DEBOUNCE.md fix ──→ (independent)
table_documentation ──→ (independent after seed)
```

Configs (psypi_config naming) → seed → setup → README/docs can all be done in parallel once config is fixed.

---

## Verification (end-to-end test)

From a fresh clone:
```bash
# 1. Prerequisites installed
node --version  # ≥ 18
gleam --version # ≥ 1.16
pi --version    # exists
pg_isready      # accepting connections

# 2. Setup
make setup      # or: bash bin/setup.sh
# Should complete without errors

# 3. Start
node bin/ppi.mjs

# 4. Inside Pi TUI:
/psypi-my-id           → S-psypi-...
/psypi-tasks           → lists tasks (empty is ok)
/psypi-skill-list      → lists 188 skills (3 local)
/psypi-skill-search query="getting-started" → finds it
/psypi-stats-show      → works
/psypi-issue-count     → works
```

---

## Open Questions

1. ~~Docker?~~ **No.** User installs PostgreSQL themselves. Setup prints install help.
2. ~~Pi auto-install?~~ **No.** Setup prints install instructions only.
3. ~~Fake Gleam cleanup?~~ **Already done.** The 6 banned modules were already replaced by real Gleam code.
