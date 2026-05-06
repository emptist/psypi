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
**Plans**: 2 plans

Plans:
- [ ] 05-01: Integrate Pi SDK, set up real agent session
- [ ] 05-02: Update inter-review system to use real Pi agent (improve score from 70/100)

#### Phase 6: Delete Legacy Projects
**Goal**: Deprecate and archive nezha/nupi codebases once psypi is fully mature
**Depends on**: Phase 5
**Plans**: 1 plan

Plans:
- [ ] 06-01: Deprecate nezha/nupi (rename to .deprecated), archive repos

#### Phase 7: Natural Gleam Growth
**Goal**: Grow Gleam core from 380 → 2000+ lines following "touch TS = rewrite in Gleam" rule
**Depends on**: Phase 4 (ongoing in parallel with Phase 5-6)
**Plans**: TBD (split into atomic 2-3 task plans as TS modules are touched)

Plans:
- [ ] 07-01: Migrate CLI routing from TypeScript to Gleam (cli.ts → Gleam main)
- [ ] 07-02: Migrate TaskService from TypeScript to Gleam
- [ ] 07-03: Migrate IssueService from TypeScript to Gleam
- [ ] 07-04: Migrate SkillService from TypeScript to Gleam
- [ ] 07-05: Migrate MeetingService from TypeScript to Gleam
- [ ] (Additional plans added as needed during natural growth)

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
| 6. Delete Legacy Projects | v1.1 | 0/1 | Not started | - |
| 7. Natural Gleam Growth | v1.1 | 0/TBD | In progress | - |
| 8. Complete Gleam Migration | v2.0 | 0/TBD | Not started | - |
