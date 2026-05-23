---
name: getting-started
description: First-time user guide for psypi. Welcome! Start here.
emoji: 🚀
---

# Getting Started with psypi

Welcome! psypi gives you two AI agents working together inside your terminal.

## What Is psypi?

psypi is a Pi TUI extension that provides:
- **S-bot** — your AI assistant. Answers questions, writes code, manages files.
- **A-bot** — autonomous monitor. Reviews commits, tracks issues, wakes S-bot when idle.
- **Shared tools** — tasks, issues, meetings, skills, code versioning, and memory.

## Your First 5 Minutes

### 1. Start Pi with psypi
```bash
cd /path/to/psypi
node bin/ppi.mjs
```

### 2. Check your identity
```
/psypi-my-id
```
You should see something like: `S-psypi-openrouter/owl-alpha`

### 3. Create your first task
```
/psypi-task-add title="Explore psypi"
```

### 4. See what's available
```
/psypi-skill-list
/psypi-issues
/psypi-stats-show
```

### 5. Search for help
```
/psypi-skill-search query="debug"
/psypi-memory-search query="setup"
```

## Common Patterns

### A-bot wake-up messages
When you're idle, A-bot may send you a message after a few minutes. This is normal — it's checking if you need help or if there's something to work on. The wait time is configurable (default: 5 minutes).

### Committing code
Use `/psypi-commit` instead of plain `git commit`. It triggers a review:
```
/psypi-commit message="Your change description"
```

### Backing up files before editing
Before AI edits a file, save a version:
```
/psypi-doc-save file_path="src/main.gleam"
```

### Meetings (A↔S discussions)
Create a meeting for structured discussions:
```
/psypi-meeting-add topic="Architecture decision" created_by="S-..."
/psypi-meeting-say meeting_id="<id>" message="I think we should..."
/psypi-meeting-opinions meeting_id="<id>"
```

## Finding Information

### Database tables
```sql
SELECT * FROM table_documentation ORDER BY id;
```

### All Pi tools
Type `/` in the Pi TUI to see all available commands.

### Memory
Agents save knowledge to memory. Search it:
```
/psypi-memory-search query="keyword"
```

## Next Steps

- Read `psypi-basics` skill for the full cheat sheet
- Read `docs/ARCHITECTURE.md` for how it works under the hood
- Run `/psypi-autonomic-health` to check system health

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `psypi-my-id` fails | Check Pi is running with psypi extension |
| Skills not found | Run `psypi-skill-list` to see what's loaded |
| Database errors | Check PostgreSQL: `pg_isready` |
| A-bot too chatty | Increase debounce: update `psypi_config.monitor_debounce_ms` |
