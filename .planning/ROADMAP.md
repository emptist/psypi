# Roadmap: psypi

## Milestones

- ✅ **v1.0 MVP** - Phases 1-4 (shipped 2026-05-04)
- 🚧 **v1.1 Gleam Migration & Real AI** - Phases 5-7 (in progress)
- 📋 **v2.0 Production Ready** - Phase 8+ (planned)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-4) - SHIPPED 2026-05-04</summary>

### Phase 1: Scaffolding
**Goal**: Set up psypi project structure, Gleam + TypeScript build system, and initial Pi extension
**Plans**: 1 plan

Plans:
- [x] 01-01: Scaffold project structure, configure Gleam + TypeScript build

### Phase 2: Integrate Kernel
**Goal**: Migrate nezha kernel (database, tasks, issues, skills) to psypi unified system
**Plans**: 2 plans

Plans:
- [x] 02-01: Database migration from nezha to psypi schema
- [x] 02-02: Port kernel services to psypi

### Phase 3: Integrate Agent
**Goal**: Migrate nupi agent features, add all 33+ Pi tools, fix build errors
**Plans**: 3 plans

Plans:
- [x] 03-01: Set up Pi extension with core tools
- [x] 03-02: Add remaining Pi tools for all CLI commands
- [x] 03-03: Fix build errors, clean up nezha/nupi pollution

### Phase 4: Replace nezha/nupi Globally
**Goal**: Make psypi the sole CLI tool, install globally, remove legacy references
**Plans**: 1 plan

Plans:
- [x] 04-01: Global pnpm install, clean `~/.pi/agent/extensions/`, update docs

</details>

### 🚧 v1.1 Gleam Migration & Real AI (In Progress)

**Milestone Goal:** Replace fake inner AI with real Pi agent, grow Gleam core to 2000+ lines, deprecate legacy projects

#### Phase 5: Replace Fake Inner AI
**Goal**: Replace stateless fake AI with real Pi agent via `createAgentSession()` (Pi SDK)
**Depends on**: Phase 4
**Status**: NOT STARTED (waiting for Pi SDK integration research)

Plans:
- [ ] 05-01: Integrate Pi SDK, set up real agent session
- [ ] 05-02: Update inter-review system to use real Pi agent (improve score from 70/100)

#### Phase 6: Delete Legacy Projects
**Goal**: Deprecate and archive nezha/nupi codebases once psypi is fully mature
**Depends on**: Phase 5
**Status**: BLOCKED - waiting for Phase 5

Plans:
- [ ] 06-01: Deprecate nezha/nupi (rename to .deprecated), archive repos

#### Phase 7: Natural Gleam Growth ✅ DONE

**Status (2026-05-10):** Complete - 26 Pi tools implemented!
**Goal**: Grow Gleam core from 380 → 2000+ lines following "touch TS = rewrite in Gleam" rule
**Strategy (2026-05-06 Breakthrough!):**
1. ✅ **TS code in PostgreSQL** (266+ versions in `code_versions` table)
2. ✅ **Flat structure** - Gleam at root, not nested
3. ✅ **Extension auto-generated** - psypi generates extension.js at startup

**Depends on**: Phase 4 (ongoing in parallel with Phase 5-6)
**Status (2026-05-09)**: IN PROGRESS - 59 Gleam modules, 6 Pi tools working!

**Completed:**
- [x] 07-01: AgentIdentityService → agent_identity.gleam + 2 tools
- [x] 07-02: DatabaseClient → db.gleam, db_query.gleam
- [x] 07-03: ApiKeyService → (part of monitor.gleam)
- [x] 07-04: TaskService → task.gleam + 2 tools
- [x] 07-09: Code versioning → code_version.gleam + doc_save tool
- [x] 07-10: Stats → stats.gleam + stats_show tool
- [x] 07-11: Extension generator → extension_generator.gleam (auto-generates extension.js!)

**Remaining (next priority):**
- [x] 07-12: Add Issue Pi tools (issue_add, issue_list, issue_resolve) ✅
- [x] 07-13: Add Skill Pi tools ✅
- [x] 07-14: Add Meeting Pi tools ✅
- [x] 07-15: Add Broadcast Pi tools ✅
- [x] 07-16: Add Learning Pi tools ✅
- [x] 07-17: Add Memory Pi tools ✅
- [x] 07-18: Add Monitor tools (consult, status, health, alerts) ✅
- [ ] 07-19: Test all tools via psypi and fix issues

**Key Achievements (2026-05-09):**
- ✅ 100% Gleam core (no more pnpm build!)
- ✅ Flat file structure (gleam.toml at root, src/psypi/)
- ✅ Auto-generated extension.js (no manual editing!)
- ✅ Pi tools via Gleam PiToolCall types (type-safe!)
- ✅ 9 working Pi tools (added issue tools)

**Code Quality Issues to Fix (later):**
- ⚠️ agentId uses String everywhere (74 occurrences) - should use custom AgentId type (use workflow improve-type-safety.md!)
- ⚠️ Many modules have unused imports (warnings)
- ⚠️ Check existing types BEFORE creating new ones (don't duplicate!)

### 📋 v2.0 Production Ready (Planned)

**Milestone Goal:** Complete Gleam migration, reach 1:5 Gleam:TS ratio, delete all unnecessary TypeScript

#### Phase 8: Complete Gleam Migration
**Goal**: Reach target ratio (2000+ Gleam lines, 10,000- TypeScript lines), delete all deprecated TS bloat
**Depends on**: Phase 7
**Plans**: TBD (3-4 plans for final cleanup)

Plans:
- [ ] 08-01: Migrate remaining core services to Gleam
- [ ] 08-02: Delete all deprecated TypeScript files
- [ ] 08-03: Update docs to reflect pure Gleam core architecture
- [ ] 08-04: Final testing and v2.0 release prep

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Scaffolding | v1.0 | 1/1 | Complete | 2026-05-02 |
| 2. Integrate Kernel | v1.0 | 2/2 | Complete | 2026-05-02 |
| 3. Integrate Agent | v1.0 | 3/3 | Complete | 2026-05-03 |
| 4. Replace nezha/nupi | v1.0 | 1/1 | Complete | 2026-05-04 |
| 5. Replace Fake Inner AI | v1.1 | 0/2 | Not started | - |
| 6. Delete Legacy Projects | v1.1 | 0/1 | Blocked | - |
| 7. Natural Gleam Growth | v1.1 | 7+/11 | In progress | 2026-05-09 |
| 8. Complete Gleam Migration | v2.0 | 0/4 | Not started | - |
