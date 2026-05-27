# Pi‑Tools Quick Reference (inside Psypi TUI)

All Pi tools are invoked from the **Psypi TUI prompt**. Just type a slash (`/`) followed by the tool name and its arguments.

## Identity
```
/psypi‑my-id                     # → returns the Somatic Agentbot ID (S‑…)
/psypi‑autonomic-id                # → returns the Atonomic Agentbot ID (A‑…)
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

## System Review
```
/psypi-review-list              # list all system reviews
/psypi-review-get <id>          # get a specific review
/psypi-review-findings <id>     # list findings for a review
/psypi-review-findings-by-severity <id> <severity>
                                 # filter findings by severity
/psypi-review-stats <id>        # severity/category breakdown
/psypi-review-update-finding <id> <number> <status>
                                 # update a finding's status
```

## Miscellaneous
```
/psypi‑hooks‑list                 # show all event hooks
/psypi‑hooks‑active               # show only active hooks
/psypi‑monitor‑status             # health of the Monitor
```

> **Tip:** Press `Enter` after typing the command; the TUI will display the tool’s output. No external shell commands are required.
