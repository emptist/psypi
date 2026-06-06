# Review: Pi Agent Tools + areflect Consolidation

**Date:** 2026-06-06
**Reviewer:** opencode (mimo-v2-pro-max)

---

## Current State: 44 Pi Agent Tools

| Category | Count | Tools |
|----------|-------|-------|
| Tools | 44 | All psypi-* tools |
| Commands | 2 | /autonomic-listen, /autonomic-reload |
| Event Hooks | 7 | tool_call, session_start, model_select, before_agent_start, agent_start, agent_end, tool_result |
| Message Renderers | 2 | autonomic-wakeup, autonomic-error |

### Tool Frequency Distribution

| Frequency | Count | Tools |
|-----------|-------|-------|
| **High** (core workflow) | 9 | psypi-my-id, psypi-task-add, psypi-tasks, psypi-task-complete, psypi-issue-add, psypi-issues, psypi-commit, psypi-issue-resolve |
| **Medium** (regular use) | 11 | psypi-stats-show, psypi-doc-save, psypi-issue-count, psypi-issue-get, psypi-learn-save, psypi-memory-search, psypi-areflect, psypi-autonomic-status, psypi-autonomic-health, psypi-autonomic-alerts |
| **Low** (infrequent/specialized) | 24 | All skill, meeting, broadcast, hook, review, finding, consult tools |

### Operation Breakdown

| Type | Count |
|------|-------|
| DB read only | 19 |
| DB write | 14 |
| File ops (git) | 1 |
| No DB/file | 1 |
| DB read + write | 1 (areflect) |

---

## `areflect` — Original Vision vs Reality

### Original Vision

From `docs/deprecated/2026-05-16-old-docs/MEMORY.md`:

> **`areflect` is the Magic Command** -- All-in-one: `[LEARN] [ISSUE] [TASK]` parsing.
> Saves to `memory`, `issues`, `tasks` tables automatically.

The idea: write text with embedded markers, call `psypi-areflect` once, everything saves. A single tool to replace multiple individual tools.

### Current Implementation (303 lines, `src/areflect.gleam`)

**Entry point:** `areflect(text, agent_id)` — parses text line-by-line for markers, saves to DB.

**Markers parsed:**

| Marker | What It Does | Destination Table |
|--------|-------------|-------------------|
| `[LEARN]` | Saves learning insight | `learning_insights` |
| `[ISSUE]` | Creates issue | `issues` |
| `[TASK]` | Creates task | `tasks` |
| `[ISSUELIST] N` | Fetches N recent issues | Read-only |

**Parsing:** Line-based. Each marker must be on its own line. Content after the marker becomes the item content. No multi-line support.

### Bugs and Gaps

**CRITICAL:**
1. **Missing `issue_type` in INSERT** — `issues` table has `issue_type` NOT NULL; areflect omits it. May rely on DB default.
2. **Error swallowing** — Individual save failures silently consumed by `promise.await` chains. Caller never knows.
3. **`agent_id` ignored in `save_learning()`** — Parameter is prefixed with `_` and not included in INSERT.

**MEDIUM:**
4. **Hardcoded severity** — All issues created as `'medium'`. No way to specify critical/high/low.
5. **Hardcoded priority** — All tasks created with priority `5`. No control.
6. **No tags on learnings** — `psypi-learn-save` accepts tags; areflect does not.
7. **Disconnected learning tables** — areflect saves to `learning_insights`; `psypi-learn-save` saves to `memory`. Two different tables for the same concept.
8. **`insight_type` hardcoded to `'pattern'`** — Table also has `'architecture'` value in data.

**LOW:**
9. No title truncation consistency (100 vs 200 chars).
10. `fetch_recent_issues` lacks `::text` casts.
11. `[ISSUELIST]` count parsing is fragile.

### Comparison: areflect vs Individual Tools

| Capability | `psypi-areflect` | Individual Tools |
|-----------|------------------|-----------------|
| Task creation | `[TASK]` line in text | `psypi-task-add` (title, desc, priority) |
| Task parameters | Hardcoded priority=5 | Full control |
| Task listing | Cannot | `psypi-tasks` with status filter |
| Task completion | Cannot | `psypi-task-complete` |
| Issue creation | `[ISSUE]` line in text | `psypi-issue-add` (title, desc, severity, type) |
| Issue parameters | Hardcoded severity=medium | Full control |
| Issue listing | Limited (recent N via [ISSUELIST]) | `psypi-issues` with filters |
| Issue resolution | Cannot | `psypi-issue-resolve` |
| Issue counting | Cannot | `psypi-issue-count` |
| Learning saving | `[LEARN]` line in text | `psypi-learn-save` (content, tags, importance) |
| Learning parameters | Hardcoded confidence=0.8, no tags | Full control |
| Learning table | `learning_insights` | `memory` (different table!) |
| Batch operation | YES — multiple markers in one call | NO — one tool call per item |
| Error handling | Silently swallowed | Per-tool error reporting |
| Return value | Counts + issue list | IDs of created items |

---

## Proposed Plan: Enhance `areflect` with Help System

### New Markers

```
[HELP]                     ← returns complete help text
[HELP] tasks               ← help for task operations
[HELP] issues              ← help for issue operations
[TASKS] pending            ← list tasks (replaces psypi-tasks)
[TASK-COMPLETE] uuid       ← complete a task (replaces psypi-task-complete)
[ISSUES] open critical     ← list issues (replaces psypi-issues)
[ISSUE-RESOLVE] uuid       ← resolve an issue (replaces psypi-issue-resolve)
[MEMORY] query here        ← search memory (replaces psypi-memory-search)
[STATS]                    ← show stats (replaces psypi-stats-show)
```

Enhanced existing markers:
```
[LEARN] [8] [gleam,ffi] content here        ← importance + tags
[ISSUE] [critical] [bug] Title — description ← severity + type
[TASK] [3] Title — description              ← priority
```

### What Stays as Individual Tools (Too Specialized)

- `psypi-my-id` — identity is fundamental, not a reflection operation
- `psypi-agents` — agent listing is meta-admin
- `psypi-autonomic-*` — monitor tools are a separate concern
- `psypi-review-*` / `psypi-finding-*` — system review is a deep specialized workflow
- `psypi-skill-*` — skill management is a separate concern
- `psypi-meeting-*` — meetings are a separate concern
- `psypi-hooks-*` — hooks are infrastructure admin
- `psypi-commit` — commit is a file operation, not a reflection
- `psypi-consult-autonomic` — consultation is a communication tool
- `psypi-doc-save` / `psypi-doc-list` — code versioning is a separate concern

### What Gets Consolidated into areflect

| Tool | Replacement Marker |
|------|-------------------|
| `psypi-tasks` | `[TASKS] pending` |
| `psypi-task-complete` | `[TASK-COMPLETE] uuid` |
| `psypi-issues` | `[ISSUES] open critical` |
| `psypi-issue-count` | `[ISSUE-COUNT] open` |
| `psypi-issue-resolve` | `[ISSUE-RESOLVE] uuid` |
| `psypi-learn-save` | `[LEARN] [8] [tag] content` |
| `psypi-memory-search` | `[MEMORY] query` |
| `psypi-stats-show` | `[STATS]` |

### Pros of Consolidation

1. AI only needs to learn one tool for all CRUD operations
2. Batch operations — create issue + task + learning in one call
3. Help system via `[HELP]` gives on-demand documentation
4. Consistent parameter parsing (severity, priority, tags)
5. Reduces tool count from 44 to ~30 (removes 14 redundant tools)

### Cons of Consolidation

1. Larger, more complex `areflect` module (currently 303 lines, would grow significantly)
2. Loses the simplicity of single-purpose tools
3. Help text adds size to the system prompt or requires a tool call
4. Breaking change for AI agents already using individual tools
5. Some tools (commit, memory-search) don't fit the "reflection" metaphor

### Recommendation

Keep high-frequency individual tools (task-add, tasks, issue-add, issues, issue-resolve) as-is — they're well-established in AI workflows. Enhance `areflect` with:

1. **`[HELP]` marker** — returns complete documentation
2. **Fix existing bugs** — missing issue_type, error swallowing, disconnected learning tables
3. **Add severity/priority/tag parsing** to markers
4. **Add read/write-back markers** — `[TASKS]`, `[ISSUES]`, `[ISSUE-RESOLVE]`, `[TASK-COMPLETE]`
5. **Consolidate low-frequency tools** — skill, meeting, broadcast, hook, review, finding tools into areflect subcommands
