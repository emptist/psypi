# Psypi Architecture Strategic Plan

## Current State Analysis (BEFORE Changes)

### TWO Separate CLIs Exist:
1. **`src/cli.ts`** → `dist/cli.js` (Main psypi binary)
   - Working commands: task-add, tasks, task-complete, issue-add, issue-list, issue-resolve, session-start/end, skill-list/show/build, areflect, learn, context, commit, announce/broadcast, inter-review-*
   - MISSING: meeting commands, agents, inner, tools subcommands

2. **`src/kernel/cli/index.ts`** → `dist/kernel/cli/index.js` (Dead code)
   - Has: meeting (discuss/list/show/opinion/complete/cleanup/archive/search/summary/recommend), agents, inner, tools, skill search/suggest, archive, revise
   - NEVER IMPORTED → Completely unused

### Evidence of Broken Architecture:
```bash
# Main CLI has NO meeting command
grep -c "case 'meeting'" dist/cli.js  # Returns: 0

# But dead CLI has it
grep -c "case 'meeting'" dist/kernel/cli/index.js  # Returns: 1

# Main CLI help doesn't show meeting
pnpm exec psypi --help | grep meeting  # Returns: NOTHING
```

## Target State ("Nezha Inside™" Done Right)

### ONE Unified CLI (`src/cli.ts` → `dist/cli.js`)
```
psypi
├── Task Commands ✅ (task-add, tasks, task-complete, task-complete-by-commit)
├── Issue Commands ✅ (issue-add, issue-list, issue-resolve)
├── Meeting Commands ⚠️ MISSING (discuss, list, show, opinion, complete, cleanup, archive, search, summary, recommend)
├── Agent Commands ⚠️ MISSING (agents id)
├── Inner AI Commands ⚠️ MISSING (inner set-model, inner model, inner review)
├── Tools Commands ⚠️ PARTIAL (need: tools search, tools learn, tools suggest)
├── Skill Commands ⚠️ PARTIAL (need: skill search, skill suggest)
├── Session Commands ✅ (session-start, session-end)
├── Memory Commands ✅ (learn, areflect)
├── Other Commands ✅ (context, commit, announce/broadcast, provider-set-key)
└── Dead Code to Remove ❌ (src/kernel/cli/index.ts, src/kernel/cli/process-guardian.ts?)
```

## Strategic Execution Plan (Thoughtful, NOT Hasty)

### Phase 1: Documentation (BEFORE Any Code Changes)
1. ✅ Create ARCHITECTURE.md documenting target state
2. ✅ Map ALL commands in both CLIs completely
3. ✅ Identify ALL dependencies needed for missing commands
4. ✅ Get approval for this plan

### Phase 2: Thoughtful Integration (Methodical)
1. **Meeting Commands Integration**
   - Add necessary imports to `cli.ts`: MeetingCommands, MeetingDbCommands, resolveMeetingId
   - Copy meeting case logic from `kernel/cli/index.ts`
   - Update help text from "nezha meeting" → "psypi meeting"
   - Test: `pnpm exec psypi meeting --help`

2. **Agent Commands Integration**
   - Add `agents` case
   - Import AgentIdentityService if needed
   - Test: `pnpm exec psypi agents id`

3. **Inner AI Commands Integration**
   - Add `inner` subcommand group
   - Import necessary services
   - Test: `pnpm exec psypi inner --help`

4. **Tools Subcommands Integration**
   - Expand `tools` command with search, suggest, learn subcommands
   - Import databaseSkillLoader, skillSystem
   - Test: `pnpm exec psypi tools --help`

5. **Skill Search/Suggest Integration**
   - Add `skill search <query>` and `skill suggest` commands
   - Test: `pnpm exec psypi skill --help`

6. **Archive & Revise Integration**
   - Add `archive <id>` and `revise <id> <text>` commands
   - Test: Verify they work

### Phase 3: Cleanup (AFTER Verification)
1. Remove `src/kernel/cli/index.ts` (dead code)
2. Check if `src/kernel/cli/process-guardian.ts` is needed
3. Remove any other orphaned files
4. Update package.json if needed

### Phase 4: Verification (Comprehensive)
1. `pnpm run build` passes
2. `pnpm exec psypi --help` shows ALL commands
3. `pnpm exec psypi meeting opinion 5d3f3973 "test" --position support` WORKS (attend the meeting!)
4. All previously working commands still work
5. Update OPEN_ISSUES.md

### Phase 5: Documentation Update
1. Create ARCHITECTURE.md (final state)
2. Update COMMANDS.md
3. Save learnings about thoughtful integration
4. Close the critical architecture issue (75a1283d)

## Why This Plan is NOT "Quick"

1. **Documentation FIRST** - No code until plan is approved
2. **Methodical phases** - One command group at a time
3. **Test after each phase** - Verify before moving on
4. **Cleanup AFTER verification** - Don't break working code
5. **Comprehensive testing** - All commands, not just new ones

## Execution Order

I will NOT start Phase 2 until:
- This plan is reviewed and approved
- All dependencies are mapped
- Test strategy is defined

"Quick is evil" - I will be thoughtful.
