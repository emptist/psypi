# Phase 7 Plan 02: Migrate Core Tools to Gleam

**Core tools already migrated to Gleam!** ✅

## Accomplishments
- ✅ **Task tools** - Already using `task.mjs` (psypi-task-add, psypi-tasks, psypi-task-complete)
- ✅ **Issue tools** - Already using `issue.mjs` (psypi-issue-add, psypi-issue-list, psypi-issue-resolve)
- ✅ **Skill tools** - Already using `skill.mjs` (psypi-skill-build, psypi-skill-list, psypi-skill-show, psypi-skill-search)
- ✅ **AgentIdentityService** - Already using `agent_identity.mjs` (from Plan 01)

## Discovery
Most tools in `extension.ts` are **already calling Gleam modules directly**!
- No thin wrappers needed (import Gleam `.mjs` directly in extension.ts)
- Each tool imports only the function it needs (e.g., `{ add }` from task.mjs)

## Files Verified
- `gleam/psypi_core/src/psypi_cli/task.gleam` - Exports: add, list, complete, get
- `gleam/psypi_core/src/psypi_cli/issue.gleam` - Exports: add, list, resolve
- `gleam/psypi_core/src/psypi_cli/skill.gleam` - Exports: create, list, show, search

## Key Insight
The "brilliant strategy" is working! TypeScript tools are calling Gleam directly via dynamic imports.

## Next Step
Ready for **07-03-PLAN.md** (Migrate remaining services)

## Verification Results
- ✅ `psypi-task-add` calls Gleam `task.add()`
- ✅ `psypi-issue-add` calls Gleam `issue.add()`
- ✅ `psypi-skill-build` calls Gleam `skill.create()`
- ✅ All Gleam modules compile (`gleam build` passes)
- ✅ No TypeScript services needed for these tools!

**Gleam migration is accelerating!** 🚀
