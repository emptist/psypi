# CLI to Pi Tool Migration Plan
**Date**: 2026-05-04  
**Goal**: Make psypi a **pure agent** - all functionality via Pi tools, deprecate CLI commands

## Architecture Principle
- **Pi tools implemented in Gleam** (core logic in `gleam/psypi_core/src/psypi_cli/`)
- **Thin TypeScript wrapper** in `src/agent/extension/extension.ts`
- **CLI commands deprecated** once Pi tool equivalent exists

---

## Current State

### ✅ Pi Tools Completed (7)
| Pi Tool | Gleam Module | CLI Equivalent | Status |
|----------|---------------|----------------|--------|
| `psypi-commit` | `review.gleam` | `psypi commit` | ✅ Done |
| `psypi-my-id` | `agent_identity.gleam` | `psypi my-id` | ✅ Done |
| `psypi-partner-id` | `agent_identity.gleam` | `psypi partner-id` | ✅ Done |
| `psypi-my-session-id` | `session.gleam` | `psypi my-session-id` | ✅ Done |
| `psypi-tasks` | `task.gleam` | `psypi tasks` | ✅ Done |
| `psypi-autonomous` | `autonomous.gleam` | `psypi autonomous` | ✅ Done |
| `psypi-status` | `status.gleam` | `psypi status` | ✅ Done |

### ⚠️ CLI Commands Needing Pi Tools (21)
| CLI Command | Pi Tool Needed | Gleam Module | Priority | Status |
|-------------|-----------------|---------------|----------|--------|
| `psypi task-add <title>` | `psypi-task-add` | `task.gleam` | HIGH | ❌ Missing |
| `psypi task-complete <id>` | `psypi-task-complete` | `task.gleam` | HIGH | ❌ Missing |
| `psypi issue-add <title>` | `psypi-issue-add` | `issue.gleam` | HIGH | ❌ Missing |
| `psypi issue-list` | `psypi-issue-list` | `issue.gleam` | HIGH | ❌ Missing |
| `psypi issue-resolve <id>` | `psypi-issue-resolve` | `issue.gleam` | HIGH | ❌ Missing |
| `psypi meeting` (subcommands) | `psypi-meeting-*` | `meeting.gleam` | HIGH | ❌ Missing |
| `psypi skill-list` | `psypi-skill-list` | `skill.gleam` | MEDIUM | ❌ Missing |
| `psypi skill-show <name>` | `psypi-skill-show` | `skill.gleam` | MEDIUM | ❌ Missing |
| `psypi skill-search <query>` | `psypi-skill-search` | `skill.gleam` | MEDIUM | ❌ Missing |
| `psypi areflect <text>` | `psypi-areflect` | `areflect.gleam` | HIGH | ❌ Missing |
| `psypi doc-list` | `psypi-doc-list` | `doc.gleam` | LOW | ❌ Missing |
| `psypi doc-save <name> <content>` | `psypi-doc-save` | `doc.gleam` | LOW | ❌ Missing |
| `psypi autonomous` | `psypi-autonomous` | `autonomous.gleam` | ✅ Done | Already exists |
| `psypi broadcast <message>` | `psypi-broadcast` | `broadcast.gleam` | MEDIUM | ❌ Missing |
| `psypi announce <message>` | `psypi-announce` | (wrapper) | LOW | ❌ Missing |
| `psypi learn <content>` | `psypi-learn` | `learn.gleam` | MEDIUM | ❌ Missing |
| `psypi stats` | `psypi-stats` | `stats.gleam` | LOW | ❌ Missing |
| `psypi visits` | `psypi-visits` | `visits.gleam` | LOW | ❌ Missing |
| `psypi project` | `psypi-project` | `project.gleam` | LOW | ❌ Missing |
| `psypi inner <subcommand>` | `psypi-inner-*` | (deprecated) | - | Skip (no external thinker) |
| `psypi inter-review-*` | `psypi-inter-review-*` | `review.gleam` | INTERNAL | Internal use |

---

## Implementation Pattern

### 1. Gleam Module (Core Logic)
```gleam
// gleam/psypi_core/src/psypi_cli/task.gleam
pub fn add(title: String, description: String, priority: Int, created_by: String) {
  // ... implementation using db.with_connection ...
}
```

### 2. TypeScript Wrapper (extension.ts)
```typescript
// src/agent/extension/extension.ts
pi.registerTool({
  name: "psypi-task-add",
  label: "PsyPI Add Task",
  description: "Add a new task to the database",
  parameters: Type.Object({
    title: Type.String({ description: "Task title" }),
    description: Type.Optional(Type.String({ description: "Task description" })),
    priority: Type.Optional(Type.Integer({ description: "Priority (1-10)", default: 5 })),
  }),
  async execute(_toolCallId: string, params: any, _signal?: AbortSignal, _onUpdate?: any, _ctx?: any) {
    try {
      // Call Gleam function via FFI or kernel
      const result = await kernel.addTask(params.title, params.description, params.priority || 5);
      return {
        content: [{ type: "text" as const, text: `Created task: ${result}` }],
        details: { taskId: result } as Record<string, unknown>,
      };
    } catch (err: any) {
      return {
        content: [{ type: "text" as const, text: `Error: ${err.message}` }],
        details: { error: true } as Record<string, unknown>,
      };
    }
  },
});
```

---

## Migration Priority

### Phase 1: Core Functionality (HIGH)
1. ✅ `psypi-commit` (Done)
2. ✅ `psypi-my-id` (Done)
3. ✅ `psypi-partner-id` (Done)
4. ✅ `psypi-my-session-id` (Done)
5. ❌ `psypi-task-add` (TODO)
6. ❌ `psypi-task-complete` (TODO)
7. ❌ `psypi-issue-add` (TODO)
8. ❌ `psypi-issue-list` (TODO)
9. ❌ `psypi-issue-resolve` (TODO)
10. ❌ `psypi-areflect` (TODO)
11. ❌ `psypi-meeting-*` (TODO - multiple subcommands)

### Phase 2: Extended Functionality (MEDIUM)
12. ❌ `psypi-skill-list` (TODO)
13. ❌ `psypi-skill-show` (TODO)
14. ❌ `psypi-skill-search` (TODO)
15. ❌ `psypi-broadcast` (TODO)
16. ❌ `psypi-learn` (TODO)

### Phase 3: Nice to Have (LOW)
17. ❌ `psypi-doc-list` (TODO)
18. ❌ `psypi-doc-save` (TODO)
19. ❌ `psypi-stats` (TODO)
20. ❌ `psypi-visits` (TODO)
21. ❌ `psypi-project` (TODO)

---

## Notes
- **2 missing items mentioned**: `psypi my-id` and `psypi partner-id` were missing but **now completed** ✅
- **Pi tools in Gleam**: Core logic in Gleam modules, TS wrapper just calls kernel/Gleam FFI
- **Deprecation**: Once a Pi tool exists, mark CLI command as deprecated (still works but prints warning)
- **Pure agent goal**: Eventually `psypi` CLI only used for `psypi commit` (which triggers Pi tool) and maybe `psypi --help`

---

## Progress
- **Done**: 7/28 (25%)
- **TODO**: 21/28 (75%)
- **Next**: Create `psypi-task-add` Pi tool (Phase 1, HIGH priority)
