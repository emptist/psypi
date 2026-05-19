---
name: psypi-basics
description: Quick cheat‑sheet for using Psypi from the TUI (Autonomic vs Somatic, IDs, common tools, commit workflow). All psypi tools are Pi agent tools — only AIs use them, not human users. Reference resources available at ../refers/pi/.
---

# Psypi Basics (for AI Agents)

> **Important:** All psypi tools are Pi agent tools. They are designed for AI agents, not human users. Humans interact with the system through the Pi TUI chat interface, not by invoking tools directly.

## Core concepts
- **Autonomic Agentbot** (`A‑…`) – autonomous, event‑driven, monitors the system.
- **Somatic Agentbot** (`S‑…`) – prompt‑driven, reacts to user or Monitor‑injected prompts.
- They are the *same AI*; the only difference is the ID prefix (`ctx.isIdle()` at call time).
- The ID is always freshly computed (no cache). Format: `(A|S)-<project>-<source>-<model>[-<thinking_level>]`
  - Example: `S-psypi-psypi-openrouter/owl-alpha` or `A-psypi-psypi-openrouter/owl-alpha-high`
  - When no `.git` found in cwd, prepends `G-` (e.g., `G-S-psypi-psypi-openrouter/owl-alpha`)
- **Pi Reference Resources** – For advanced Pi patterns, see `/Users/jk/gits/hub/tools_ai/refers/pi/` with prompts like `cl.md` (changelog), `is.md` (issue analysis), `pr.md` (PR review), `wr.md` (work wrapup)

## Getting your identity
```
/psypi-somatic-id       # returns Somatic Agentbot ID (S-…)
/psypi-autonomic-id     # returns Autonomic Agentbot ID (A-…)
```
Both call the same pure function `get_resolved_identity(ctx)` — the prefix is determined by `ctx.isIdle()` at the moment of the call.

## Common Pi-tools (use **inside the Psypi TUI**; just type a leading `/`)

### Tasks
```
/psypi-task-add title="Write docs"
    → creates a task, returns its UUID. (title required)
/psypi-tasks [status="pending"] [project_id="..."]
    → lists tasks, optionally filtered. (all params optional)
/psypi-task-complete task_id="<uuid>"
    → marks a task as completed.
```

### Issues
```
/psypi-issue-add title="Bug" description="Details" severity="high" issue_type="bug"
    → creates an issue. (all params required)
/psypi-issues [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
    → lists issues with optional filters.
/psypi-issue-count [status="open"] [severity="high"] [issue_type="bug"] [project_id="..."]
    → counts issues matching filters.
/psypi-issue-get id="<uuid>"
    → gets a single issue by ID.
/psypi-issue-resolve id="<uuid>"
    → resolves an issue by ID.
```

### Reflection (parse markdown markers)
```
/psypi-areflect text="... [LEARN] ... [ISSUE] ... [TASK] ... [ISSUELIST] ..."
    → Parses [LEARN], [ISSUE], [TASK], [ISSUELIST] markers from text and saves to DB.
```

### Commit with Monitor review
```
/psypi-commit message="Refactor ID handling"
    → runs Monitor review, shows PASS/FAIL + score, returns review_id on pass.
/psypi-commit message="Refactor ID handling" review_id="<uuid>"
    → skips review, commits directly with a valid review_id.
```

### Meetings (discussion between Somatic and Autonomic workers)
```
/psypi-meeting-add topic="Discussion topic" created_by="S-..."
    → creates a new meeting, returns meeting ID.
/psypi-meeting-say meeting_id="<id>" message="Your opinion"
    → adds your opinion to a meeting.
/psypi-meeting-opinions meeting_id="<id>"
    → lists all opinions for a meeting.
/psypi-meetings [status="active"]
    → lists meetings, optionally filtered by status.
/psypi-meeting-get id="<id>"
    → gets a single meeting by ID.
```

### Skills
```
/psypi-skill-list [status="installed"]
    → lists skills, optionally filtered by status.
/psypi-skill-get id="<name>"
    → gets a skill by name.
/psypi-skill-search query="gleam"
    → searches skills by name/description.
```

### Learning & Memory
```
/psypi-learn-save content="..." tags="tag1,tag2" importance="5"
    → saves a learning to memory.
/psypi-memory-search query="keyword" limit="10"
    → searches memories by keyword.
```

### Broadcast
```
/psypi-broadcast-send message="Hello" priority="normal" project_id="psypi"
    → sends a broadcast message.
/psypi-broadcasts limit="10"
    → lists recent broadcast messages.
```

### Agents
```
/psypi-agents
    → lists all registered agents from the database.
```

### Monitor / Autonomic status
```
/psypi-autonomic-status
    → returns Monitor status and capabilities.
/psypi-autonomic-health
    → returns system health metrics (failed tasks, open issues, activity).
/psypi-autonomic-alerts
    → returns active alerts (failed tasks, open issues).
/psypi-autonomic-stats
    → returns Monitor statistics (review scores, response times, failure rate).
/psypi-autonomic-suggest
    → returns work suggestions (open issues, stale tasks, pending skills).
```

### Event hooks
```
/psypi-hooks-list
    → lists all psypi event hooks and their status.
/psypi-hooks-active
    → lists only active psypi event hooks.
```

### Directives (Autonomic → Somatic communication)
```
/psypi-direct-agentbot directive_text="Focus on testing" priority="high"
    → Autonomic Agentbot injects a directive into Somatic's system prompt.
/psypi-clear-directives
    → clears all active system directives.
```

### Consult (Somatic asks Autonomic for advice)
```
/psypi-consult-autonomic question="Should I refactor this module?"
    → Somatic asks Autonomic for advice on a difficult decision.
```

### Code versioning
```
/psypi-doc-save file_path="src/main.gleam"
    → saves a file version to code_versions table (auto-backup before edits).
/psypi-doc-list file_path="src/main.gleam" limit="10"
    → lists version history for a file.
```

### Stats
```
/psypi-stats-show
    → shows project statistics (tasks, issues, skills, meetings counts).
```

## Slash commands (human-facing, for Monitor interaction)
These are registered as Pi commands, not Pi tools:
```
/autonomic-listen <message>
    → Human talks to Monitor AI directly in chat.
/autonomic-reload
    → Reloads Pi extensions (used after Monitor modifies its own Gleam code).
```

## Important usage notes
- **Never run Pi tools as shell commands** (e.g. `psypi-task-add`). They exist only inside the Pi runtime (`extension.js`). Attempting to call them from the OS will result in "command not found".
- Always invoke them from the **Psypi TUI** prompt.
- **Never cache the ID.** It must be computed fresh every time because `ctx.isIdle()` is live.

## Pi Prompt Patterns (from refer resources)
Reference Pi prompts available at `../refers/pi/.pi/prompts/`:
- **`cl.md`** – Audit changelog entries before release
- **`is.md`** – Analyze GitHub issues (bugs or feature requests)
- **`pr.md`** – Review PRs from URLs with structured issue and code analysis
- **`wr.md`** – Finish the current task end-to-end with changelog, commit, and push

These can be used by both Autonomic and Somatic agents for standard Pi workflows.

## Quick tip
- After any change, run `/psypi-commit` to let the Monitor review and approve the commit. This keeps the single-dreamer cycle safe and autonomous.
