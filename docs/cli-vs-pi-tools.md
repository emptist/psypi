# CLI Commands vs Pi Tools Comparison

## CLI Commands (from src/cli.ts)

| CLI Command                     | Has Pi Tool? | Pi Tool Name              | Status                    |
| ------------------------------- | ------------ | ------------------------- | ------------------------- |
| `task-add <title>`              | Yes          | `psypi-task-add`           | Done                      |
| `tasks`                         | Yes          | `psypi-tasks`             | Done                      |
| `task-complete <taskId>`        | Yes          | `psypi-task-complete`     | Done                      |
| `issue-add <title>`             | Yes          | `psypi-issue-add`         | Done                      |
| `issue-list`                    | Yes          | `psypi-issue-list`        | Done                      |
| `issue-resolve <issueId>`       | Yes          | `psypi-issue-resolve`     | Done                      |
| `skill-list`                    | Yes          | `psypi-skill-list`        | Done                      |
| `skill-show <name>`             | Yes          | `psypi-skill-show`        | Done                      |
| `skill-build <name> <purpose>`  | Yes          | `psypi-skill-build`        | Done (TS, calls Gleam)    |
| `provider-set-key <provider>`   | No           | -                         | Missing                   |
| `areflect <text>`               | Yes          | `psypi-areflect`          | Done                      |
| `learn <content>`               | Yes          | `psypi-learn`              | Done (TS)                |
| `my-id`                         | Yes          | `psypi-my-id`             | Done                      |
| `partner-id`                    | Yes          | `psypi-partner-id`        | Done                      |
| `commit <message>`              | Yes          | `psypi-commit`            | Done                      |
| `announce <message>`            | Yes          | `psypi-announce`           | Done (TS, calls Gleam)    |
| `broadcast <message>`           | Yes          | `psypi-broadcast-send`    | Done                      |
| `inter-review-request <taskId>` | Yes          | `psypi-inter-review-request` | Done (TS)             |
| `inter-review-show <reviewId>`  | Yes          | `psypi-inter-review-show` | Done (TS)                 |
| `inter-reviews [status]`        | Yes          | `psypi-inter-reviews`      | Done (TS)                 |
| `inner set-model`               | Yes          | `psypi-monitor-set-model` | Done                      |
| `inner model`                   | Yes          | `psypi-partner-id`        | Done (same as partner-id) |
| `inner review`                  | Yes          | `psypi-monitor-review`    | Done                      |
| `status`                        | Yes          | `psypi-status`            | Done                      |
| `doc-save <name> <content>`     | Yes          | `psypi-doc-save`          | Done                      |
| `doc-list`                      | Yes          | `psypi-doc-list`          | Done                      |
| `autonomous [context]`          | Yes          | `psypi-autonomous`        | Done                      |
| `project`                       | Yes          | `psypi-project`           | Done                      |
| `stats`                         | Yes          | `psypi-stats`             | Done                      |
| `tools`                         | Yes          | `psypi-tools`              | Done (TS)                 |
| `agents`                        | Yes          | `psypi-agents`             | Done (TS)                 |
| `visits`                        | Yes          | `psypi-visits`            | Done                      |
| `validate-commit <message>`     | Yes          | `psypi-validate-commit`    | Done (TS)                 |
| `meeting <subcommand>`          | Yes          | `psypi-meeting-*`         | Done                      |
| `help [command]`                | Yes          | `psypi-help`               | TODO (Gleam main)        |

## `inner` Command → `monitor`

The `inner` command is **misleadingly named**. It's actually about the **Monitor AI** (the "God AI" that reviews commits).

**Universal name: Monitor** - Use `monitor` instead of `inner` when building Pi tools.

| Subcommand                           | What it does                          | Pi Tool                   | Status |
| ------------------------------------ | ------------------------------------- | ------------------------- | ------ |
| `inner set-model [provider] [model]` | Set the Monitor AI model         | `psypi-monitor-set-model` | Done   |
| `inner model`                        | Get Monitor ID (same as `partner-id`) | `psypi-partner-id`        | Done   |
| `inner monitor-model`                 | Get Monitor AI model                | `psypi-monitor-model`     | NEW    |
| `inner review`                       | Run inter-review by Monitor AI        | `psypi-monitor-review`    | Done   |

**Recommendation**: Rename `inner` CLI to `monitor` for clarity.

## Missing Pi Tools

| Priority | CLI Command            | Suggested Pi Tool Name       | Description               |
| -------- | ---------------------- | ---------------------------- | ------------------------- |
| High     | `task-add`             | `psypi-task-add`             | Add a new task            |
| High     | `task-complete`        | `psypi-task-complete`        | Complete a task           |
| High     | `learn`                | `psypi-learn`                | Save a learning           |
| High     | `skill-build`          | `psypi-skill-build`          | Build a new skill         |
| Medium   | `announce`             | `psypi-announce`             | Announce to all AIs       |
| Medium   | `inter-review-request` | `psypi-inter-review-request` | Request inter-review      |
| Medium   | `inter-reviews`        | `psypi-inter-reviews`        | List inter-reviews        |
| Medium   | `inter-review-show`    | `psypi-inter-review-show`    | Show inter-review details |
| Medium   | `provider-set-key`     | `psypi-provider-set-key`     | Set API key for provider  |
| Low      | `tools`                | `psypi-tools`                | List tools                |
| Low      | `agents`               | `psypi-agents`               | List agents               |
| Low      | `validate-commit`      | `psypi-validate-commit`      | Validate commit message   |

## Pi Tools without CLI Commands

| Pi Tool Name           | Description                    |
| ---------------------- | ------------------------------ |
| `psypi-doc-restore`    | Restore a file version         |
| `psypi-skill-search`   | Search skills by keyword       |
| `psypi-broadcast-list` | List broadcast messages         |
| `psypi-monitor-model`  | Show Monitor AI model (new!)   |

Note: These Pi tools exist in the extension but don't have corresponding CLI commands.

## Summary
- Total CLI commands: 34
- CLI with Pi tools: 33 (all except `provider-set-key` and `help`)
- CLI without Pi tools: 2 (`provider-set-key`, `help`)
- Pi tools without CLI: 3 (`psypi-doc-restore`, `psypi-skill-search`, `psypi-broadcast-list`)
- All major CLI commands now have Pi tools!
- `inner` command should be renamed to `monitor` for clarity
- **Universal name: Monitor** - Use `monitor` in all Pi tool names
- ⚠️ `psypi-my-session-id` is NOT a real Pi tool (only mentioned in status text)
- ✅ New tools added: `psypi-task-add`, `psypi-task-complete`, `psypi-learn`, `psypi-skill-build`, `psypi-announce`, `psypi-inter-review-*`, `psypi-tools`, `psypi-agents`, `psypi-validate-commit`
