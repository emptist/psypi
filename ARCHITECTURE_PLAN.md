# Psypi Architecture Strategic Plan

## 🎯 Core Philosophy: Gleam Core + TypeScript Thin Wrapper

> **User's Vision**: "原有的ts代码，如果适合用gleam重写的，就重写，如果不适合gleam重写的，就保留ts，这样大部分的代码可以变成小巧强健的 gleam 模块，而ts最终变成 thin wrapper，极少数不适合用gleam写的除外。"

### The "Bypass Middleware" Principle

**越过冗余的中间拥堵层，直奔唯一真相：**

| 真相          | 来源                                         | ❌ 错误做法                    | ✅ 正确做法   |
| ------------- | -------------------------------------------- | ----------------------------- | ------------ |
| Pi Session ID | `ctx.sessionManager.getSessionId()`          | `kernel.piSessionID()` 中间层 | 直接用 `ctx` |
| Agent ID      | `AgentIdentityService.getResolvedIdentity()` | 缓存、中间方法                | 每次直接调用 |

**Why?** 中间层增加复杂度、隐藏真相、制造混乱。Gleam 重写时要直接连接真相源。

### Gleam vs TypeScript 边界

```
┌─────────────────────────────────────────────────────────┐
│                    Gleam Core (强健)                     │
│  - 类型安全的业务逻辑                                    │
│  - 数据库操作 (node_pg)                                  │
│  - 数据解码/验证                                         │
│  - 纯函数、无副作用                                      │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ 直接调用
                          │
┌─────────────────────────────────────────────────────────┐
│                TypeScript Thin Wrapper                   │
│  - CLI 入口 (commander)                                  │
│  - Pi Extension 集成                                     │
│  - 外部库调用 (Pi SDK 等)                                │
│  - Node.js 特有操作                                      │
└─────────────────────────────────────────────────────────┘
```

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

## Target State ("PsyPI Inside™" Done Right)

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

### Phase 2: Thoughtful Integration (Methodical) ✅ COMPLETE
1. **Meeting Commands Integration** ✅
   - Add necessary imports to `cli.ts`: MeetingCommands, MeetingDbCommands, resolveMeetingId
   - Copy meeting case logic from `kernel/cli/index.ts`
   - Update help text from "nezha meeting" → "psypi meeting"
   - Test: `pnpm exec psypi meeting --help`

2. **Agent Commands Integration** ✅
   - Add `agents` case
   - Import AgentIdentityService if needed
   - Test: `pnpm exec psypi agents id`

3. **Inner AI Commands Integration** ✅
   - Add `inner` subcommand group
   - Import necessary services
   - Test: `pnpm exec psypi inner --help`

4. **Tools Subcommands Integration** ✅
   - Expand `tools` command with search, suggest, learn subcommands
   - Import databaseSkillLoader, skillSystem
   - Test: `pnpm exec psypi tools --help`

5. **Skill Search/Suggest Integration** ⏳ (Optional - not critical)
   - Add `skill search <query>` and `skill suggest` commands
   - Test: `pnpm exec psypi skill --help`

6. **Archive & Revise Integration** ⏳ (Optional - not critical)
   - Add `archive <id>` and `revise <id> <text>` commands
   - Test: Verify they work

### Phase 3: Cleanup (AFTER Verification) ✅ COMPLETE
1. ✅ Deprecated `src/kernel/cli/index.ts` (moved to `src/deprecated/cli.kernel.deprecated.ts`)
2. ⏳ Check if `src/kernel/cli/process-guardian.ts` is needed (kept for now)
3. ✅ No other orphaned files found
4. ✅ No package.json changes needed

### Phase 4: Verification (Comprehensive) ✅ COMPLETE
1. ✅ `pnpm run build` passes
2. ✅ `pnpm exec psypi --help` shows ALL commands (34 commands)
3. ✅ `gleam test` passes (24 tests)
4. ✅ All previously working commands still work
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
