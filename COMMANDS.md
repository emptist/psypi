# Psypi Command Reference - Complete Migration Table

> **Comprehensive comparison of ALL commands from nezha, nupi, and their status in psypi**

## Legend
- ✅ **Working** (tested, functional)
- ➕ **Added** (source code exists, but build broken)
- ⚠️ **Partial** (works via old compiled version)
- ❌ **Missing** (not yet implemented)
- 🔄 **Renamed** (different name in psypi)
- **Alias** (alternative name for same command)

---

## Core Commands Comparison Table

| Nezha Command | Nupi Command | Psypi Command | Status | Notes |
|---------------|--------------|---------------|--------|-------|
| `task-add <title> [desc]` | - | `task-add <title> [desc]` | ✅ Working ⚠️ | Old compiled version works |
| `tasks [--status]` | `nupi-tasks` | `tasks [--status]` | ✅ Working ⚠️ | Supports `--json`, `next` subcmd |
| `task-complete <id>` | - | `task-complete <id>` | ➕ Added | Build broken, can't test |
| `task-complete-by-commit <msg>` | - | `task-complete-by-commit <msg>` | ➕ Added | Build broken, can't test |
| `issue-add <title> [--severity]` | - | `issue-add <title> [--severity]` | ✅ Working ⚠️ | **Issue reporting works great!** |
| `issue-list [--status]` | - | `issue-list [--status]` | ➕ Added | Was `issues`, renamed to match nezha |
| `issue-resolve <id> [notes]` | - | `issue-resolve <id> [notes]` | ➕ Added | Build broken, can't test |
| `meeting discuss <t> <d>` | `nupi-meeting-say` | `meeting discuss <t> <d>` | ❌ Missing | Full meeting subsystem |
| `meeting list [--limit] [--status]` | `nupi-meeting-list` | `meeting list [--limit] [--status]` | ❌ Missing | |
| `meeting show <id>` | `nupi-meeting-summary` | `meeting show <id>` | ❌ Missing | |
| `meeting opinion <id> <perspective>` | - | `meeting opinion <id> <perspective>` | ❌ Missing | |
| `meeting complete <id> [consensus]` | - | `meeting complete <id> [consensus]` | ❌ Missing | |
| `meeting cleanup [--days]` | - | `meeting cleanup [--days]` | ❌ Missing | |
| `meeting archive [--days]` | - | `meeting archive [--days]` | ❌ Missing | |
| `meeting search <term>` | `nupi-meeting-search` | `meeting search <term>` | ❌ Missing | |
| `meeting summary <id>` | - | `meeting summary <id>` | ❌ Missing | |
| `meeting recommend <keyword>` | - | `meeting recommend <keyword>` | ❌ Missing | |
| `announce <msg> [--priority]` | - | `announce <msg> [--priority]` | ➕ Added | Build broken, can't test |
| `broadcast <msg> [--priority]` | - | `broadcast <msg> [--priority]` | ➕ Added | Alias for `announce` |
| `agents id` | - | `agents id` | ❌ Missing | |
| `inner set-model [provider] [model]` | `nupi-sync-inner-ai` | `inner set-model [provider] [model]` | ❌ Missing | Inner AI management |
| `inner model` | - | `inner model` | ❌ Missing | Show inner AI agent ID |
| `inner review` | - | `inner review` | ❌ Missing | Invoke Inner AI review |
| `context [--json] [--for]` | - | `context [--json] [--for]` | ✅ Working ⚠️ | Shows current context |
| `tools [tool-name]` | - | `tools [tool-name]` | ✅ Working | List tools from DB |
| `learnTheseFirst` / `learn-first` | - | `tools learn` (subcmd) | ✅ Working | Merged into `tools learn` |
| `validate-commit <file>` | - | `validate-commit <file>` | ✅ Working | Validates commit messages |
| `skill list` | - | `skill-list` | ✅ Working ⚠️ | Renamed (no space) |
| `skill show <name>` | - | `skill-show <name>` | ✅ Working ⚠️ | Renamed (no space) |
| `skill search <query>` | - | `skill-search <query>` | ❌ Missing | |
| `skill build <name> <purpose>` | - | `skill-build <name> <purpose>` | ✅ Working ⚠️ | Renamed (no space) |
| `skill suggest [--context]` | - | `skill-suggest [--context]` | ❌ Missing | |
| `learn <insight>` | - | `learn <insight>` | ✅ Working | Save learning to memory |
| `archive <id> [--reason]` | - | `archive <id> [--reason]` | ❌ Missing | |
| `revise <id> <new-content>` | - | `revise <id> <new-content>` | ❌ Missing | |
| `areflect <text>` | - | `areflect <text>` | ✅ Working ⚠️ | All-in-one magic command |
| `inter-review-request <taskId>` | - | `inter-review-request <taskId>` | ➕ Added | Build broken, can't test |
| `inter-review-show <reviewId>` | - | `inter-review-show <reviewId>` | ✅ Working | Show inter-review details |
| `inter-reviews [status]` | - | `inter-reviews [status]` | ✅ Working | List inter-reviews |
| `provider-set-key <provider>` | - | `provider-set-key <provider>` | ✅ Working | Set API key (encrypts with NEZHA_SECRET) |
| `commit <message>` | - | `commit <message>` | ✅ Working | Git commit with quality control |

---

## Nupi-Only Commands (Pi Integration)

| Nupi Command | Psypi Command | Status | Notes |
|--------------|---------------|--------|-------|
| `nupi-think <question>` | `think <question>` | ❌ Missing | Delegate to external thinker (Piano/OpenCode) |
| `nupi-autonomous [context]` | `autonomous [context]` | ❌ Missing | Get guidance for autonomous work |
| `nupi-meeting-say <id> <perspective>` | `meeting opinion <id> <perspective>` | ❌ Missing | (covered by meeting subsystem) |
| `nupi-meeting-summary <id>` | `meeting show <id>` | ❌ Missing | (covered by meeting subsystem) |
| `nupi-meeting-search <query>` | `meeting search <query>` | ❌ Missing | (covered by meeting subsystem) |
| `nupi-meeting-list [status]` | `meeting list [status]` | ❌ Missing | (covered by meeting subsystem) |
| `nupi-doc-save <name> <content>` | `doc-save <name> <content>` | ❌ Missing | Save project document to DB |
| `nupi-doc-list [project]` | `doc-list [project]` | ❌ Missing | List project documents |
| `nupi-status` | `status` | ❌ Missing | Show NuPI/Psypi status |
| `nupi-project` | `project` | ❌ Missing | Show current project info |
| `nupi-visits [limit]` | `visits [limit]` | ❌ Missing | Show recent project visits |
| `nupi-stats` | `stats` | ❌ Missing | Show ecosystem statistics |
| `nupi-sync-inner-ai` | `inner set-model` | ❌ Missing | (covered by inner subsystem) |

---

## Session Management Commands

| Nezha Command | Nupi Command | Psypi Command | Status | Notes |
|---------------|--------------|---------------|--------|-------|
| - | `before_agent_start` (hook) | `session-start` | ✅ Working ⚠️ | Auto-loads project-onboarding skill |
| - | `after_agent_end` (hook) | `session-end` | ✅ Working ⚠️ | Updates session status |
| - | - | `setup-hooks` | ➕ Added | Install git hooks (build broken) |

---

## Summary Statistics

### By Status:
| Status | Count | Percentage |
|--------|-------|------------|
| ✅ Working (old compiled version) | 11 | ~30% |
| ➕ Added (source code, build broken) | 12 | ~32% |
| ❌ Missing (not yet implemented) | 14+ | ~38% |
| **Total Commands** | **37+** | **100%** |

### By Source:
| Source | Count |
|--------|-------|
| From Nezha | 28+ |
| From Nupi | 13 |
| Unique to Psypi | 1 (`setup-hooks`) |

---

## Name Changes (Nezha → Psypi)

| Nezha | Psypi | Reason |
|-------|-------|--------|
| `skill list` | `skill-list` | CLI convention (no space) |
| `skill show <name>` | `skill-show <name>` | CLI convention (no space) |
| `skill build <name> <purpose>` | `skill-build <name> <purpose>` | CLI convention (no space) |
| `issue-list` | `issue-list` | Same (was `issues` in early psypi) |
| `learnTheseFirst` / `learn-first` | `tools learn` | Merged into `tools` command |
| `nupi-think` | `think` | Simplified (drop nupi- prefix) |
| `nupi-autonomous` | `autonomous` | Simplified (drop nupi- prefix) |

---

## Build-Blocking Errors (Preventing Testing)

All 12 "➕ Added" commands **cannot be tested** due to 4 TypeScript errors:

1. **`f8f96dbd`**: `AgentIdentityService.ts(1,8)` — crypto import
2. **`eb836ac5`**: `Config.ts(25,21)` — Expression expected
3. **`b8db9983`**: `kernel/index.ts(233,27)` — Set<string> needs downlevelIteration
4. **`0ea2b844`**: `cli.ts(35,10)` — Can't find exported member 'kernel'

---

## Priority Implementation Order (Suggested)

### Phase 1: Fix Build (Blocker for Everything)
1. Fix 4 TypeScript errors
2. Get clean build
3. Test all 12 "➕ Added" commands

### Phase 2: Core Missing Commands (High Priority)
1. `inner` subsystem (set-model, model, review)
2. `agents id` (simple)
3. `archive` and `revise` (memory management)
4. `skill search` and `skill suggest`

### Phase 3: Meeting Subsystem (Medium Priority)
1. `meeting discuss` (create meetings)
2. `meeting list`, `meeting show`
3. `meeting opinion`, `meeting summary`

### Phase 4: Nupi Integration (Lower Priority)
1. `think` (external thinker)
2. `autonomous` (autonomous work)
3. `doc-save`, `doc-list`
4. `status`, `project`, `visits`, `stats`

---

**Last Updated**: $(date)
**Build Status**: ❌ BROKEN (4 TypeScript errors)
**Issue Reporting**: ✅ WORKING (`psypi issue-add` functions perfectly)
