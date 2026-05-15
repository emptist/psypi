---
name: psypi-basics
description: Quick cheat‑sheet for using Psypi from the TUI (Atonomic vs Somatic, IDs, common tools, commit workflow).
---

# Psypi Basics (for AIs)

## Core concepts
- **Atonomic Worker** (`A‑…`) – autonomous, event‑driven, monitors the system.
- **Somatic Worker** (`S‑…`) – prompt‑driven, reacts to user or Monitor‑injected prompts.
- They are the *same AI*; the only difference is the ID prefix.
- The ID is always freshly computed (no cache) and bound to a `souls` row.

## Getting your identity
```
/psypi‑my-id          # returns Somatic Worker ID (S‑…)
/psypi‑monitor-id     # returns Atonomic Worker ID (A‑…)
```

## Common Pi‑tools (use **inside the Psypi TUI**; just type a leading `/`)
### Tasks
```
/psypi‑task‑add title="Write docs" description="Add pi‑tools.md"
    → creates a task, returns its UUID.
/psypi‑tasks           # list open tasks
/psypi‑task‑complete <task‑id>
```
### Issues & learning
```
/psypi‑issue‑add title="Bug in hook" severity="high"
/psypi‑issues          # list issues
/psypi‑areflect <markdown>
    # Parses [LEARN], [ISSUE], [TASK] blocks and stores them.
```
### Commit with Monitor review
```
/psypi‑commit "Refactor ID handling"
    # Runs a review, shows PASS/FAIL, then git‑commits.
```
### Hooks & monitor status
```
/psypi‑hooks‑list      # all event hooks
/psypi‑hooks‑active    # only active hooks
/psypi‑monitor‑status  # health of the Monitor
```

## Important usage note
- **Never run Pi tools as shell commands** (e.g. `psypi‑task‑add`). They exist only inside the Pi runtime (`extension.js`). Attempting to call them from the OS will result in “command not found”.
- Always invoke them from the **Psypi TUI** prompt.

## Quick tip
- After any change, run `/psypi‑commit` to let the Monitor review and approve the commit. This keeps the single‑dreamer cycle safe and autonomous.
