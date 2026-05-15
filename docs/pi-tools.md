# Pi‑Tools Quick Reference (inside Psypi TUI)

All Pi tools are invoked from the **Psypi TUI prompt**. Just type a slash (`/`) followed by the tool name and its arguments.

## Identity
```
/psypi‑my-id                     # → returns the Somatic Worker ID (S‑…)
/psypi‑monitor-id                # → returns the Atonomic Worker ID (A‑…)
```

## Task management
```
/psypi‑task‑add title="Write docs" description="Add pi‑tools.md"
    → creates a new task and returns its UUID.

/psypi‑tasks                     # list all open tasks
/psypi‑task‑complete <task-id>   # mark a task as done
```

## Issues & Learning
```
/psypi‑issue‑add title="Bug in hook" severity="high"
    → creates an issue.

/psypi‑issues                    # list all issues
/psypi‑areflect <markdown>       # parses [LEARN], [ISSUE], [TASK] blocks
```

## Commit with review
```
/psypi‑commit "Refactor ID handling"
    → runs the Monitor review, shows PASS/FAIL, then commits.
```

## Miscellaneous
```
/psypi‑hooks‑list                 # show all event hooks
/psypi‑hooks‑active               # show only active hooks
/psypi‑monitor‑status             # health of the Monitor
```

> **Tip:** Press `Enter` after typing the command; the TUI will display the tool’s output. No external shell commands are required.
