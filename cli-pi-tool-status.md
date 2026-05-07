# CLI Commands to Pi Tool Promotion Status

This table lists which CLI commands have been promoted to Pi tools, based on code analysis (checking `src/agent/extension/extension.js` and related files).

| CLI Command                     | Promoted to Pi Tool? | Pi Tool Name                  | Status (Code Check)                          |
| ------------------------------- | -------------------- | ----------------------------- | -------------------------------------------- |
| `task-add <title>`              | ✅ Yes               | `psypi-task-add`              | Found in extension.js                        |
| `tasks`                         | ✅ Yes              | `psypi-tasks`                  | Found in extension.js + **TESTED!**         |
| `task-complete <taskId>`        | ✅ Yes               | `psypi-task-complete`         | Found in extension.js                        |
| `issue-add <title>`             | ✅ Yes               | `psypi-issue-add`             | Found in extension.js                        |
| `issue-list`                    | ✅ Yes               | `psypi-issue-list`            | Found in extension.js                        |
| `issue-resolve <issueId>`       | ✅ Yes               | `psypi-issue-resolve`         | Found in extension.js                        |
| `skill-list`                    | ✅ Yes               | `psypi-skill-list`            | Found in extension.js                        |
| `skill-show <name>`             | ✅ Yes               | `psypi-skill-show`            | Found in extension.js                        |
| `skill-build <name> <purpose>`  | ✅ Yes               | `psypi-skill-build`           | Found in extension.js                        |
| `provider-set-key <provider>`   | ❌ No                | -                             | No Pi tool planned/documented                |
| `areflect <text>`               | ✅ Yes               | `psypi-areflect`              | Found in extension.js                        |
| `learn <content>`               | ✅ Yes               | `psypi-learn`                 | Found in extension.js                        |
| `my-id`                         | ✅ Yes               | `psypi-my-id`                 | Found in extension.js                        |
| `partner-id`                    | ✅ Yes               | `psypi-partner-id`            | Found in extension.js                        |
| `commit <message>`              | ❌ No                | `psypi-commit` (documented)   | Not found in code                             |
| `announce <message>`            | ❌ No                | `psypi-announce` (documented) | Not found in code                             |
| `broadcast <message>`           | ✅ Yes               | `psypi-broadcast-send`        | Found in extension.js                        |
| `inter-review-request <taskId>` | ✅ Yes               | `psypi-inter-review-request`  | Found in extension.js                        |
| `inter-review-show <reviewId>`  | ✅ Yes               | `psypi-inter-review-show`     | Found in extension.js                        |
| `inter-reviews [status]`        | ✅ Yes               | `psypi-inter-reviews`         | Found in extension.js                        |
| `inner set-model`               | ❌ No                | `psypi-monitor-set-model`     | Not found in code                             |
| `inner model`                   | ✅ Yes               | `psypi-partner-id`            | Same as partner-id (found)                   |
| `inner review`                  | ❌ No                | `psypi-monitor-review`        | Not found in code                             |
| `status`                        | ❌ No                | `psypi-status` (documented)   | Not found in code                             |
| `doc-save <name> <content>`     | ❌ No                | `psypi-doc-save` (documented) | Not found in code                             |
| `doc-list`                      | ❌ No                | `psypi-doc-list` (documented) | Not found in code                             |
| `autonomous [context]`          | ❌ No                | `psypi-autonomous` (documented) | Not found in code                           |
| `project`                       | ❌ No                | `psypi-project` (documented)  | Not found in code                             |
| `stats`                         | ✅ Yes               | `psypi-stats`                 | Found in extension.js + **TESTED!**         |
| `tools`                         | ❌ No                | `psypi-tools` (documented)    | Not found in code                             |
| `agents`                        | ✅ Yes               | `psypi-agents`                | Found in extension.js                        |
| `visits`                        | ❌ No                | `psypi-visits` (documented)   | Not found in code                             |
| `validate-commit <message>`     | ❌ No                | `psypi-validate-commit`       | Not found in code                             |
| `meeting <subcommand>`          | ✅ Yes               | `psypi-meeting-*`             | Multiple meeting tools found in extension.js |
| `help [command]`                | ❌ No                | `psypi-help` (documented)     | Not found in code                             |

## Summary
- **Promoted to Pi Tools (found in code):** 30 tools (was 29!)
- **Documented but not found in code:** 12 tools
- **No Pi tool planned:** 1 tool (`provider-set-key`)

## Notes
- The main extension file `src/agent/extension/extension.js` contains 30 registered Pi tools.
- Many tools documented as "Done" in `docs/cli-vs-pi-tools.md` are not present in the code.
- Missing tools may be in other extension files, deprecated, or not yet implemented.
- Verified tools in extension.js: psypi-my-id, psypi-partner-id, psypi-agents, psypi-task-add, psypi-task-complete, **psypi-tasks (NEW!)**, psypi-skill-build, psypi-skill-list, psypi-skill-show, psypi-skill-search, psypi-issue-add, psypi-issue-list, psypi-issue-resolve, psypi-system-health, psypi-system-housekeeping, psypi-learn, psypi-areflect, psypi-broadcast-send, psypi-broadcast-list, psypi-meeting-*, psypi-inter-review-*, psypi-stats.
