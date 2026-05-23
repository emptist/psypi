# Monitor Debounce Time

The Autonomic Agentbot (Monitor) waits after the Somatic Agentbot goes idle before sending a wake-up message.

## Configuration

- **Key:** `monitor_debounce_ms`
- **Default:** 300000ms (5 minutes)
- **Current:** 900000ms (15 minutes) — extended during active development to avoid interruptions
- **Location:** `psypi_config` table

## Setting a Custom Value

```sql
UPDATE psypi_config SET value = '300000' WHERE key = 'monitor_debounce_ms';
```

Values (in milliseconds):
- 300000 = 5 minutes (default)
- 120000 = 2 minutes
- 60000 = 1 minute

## How It Works

1. When `agent_end` fires (S-agentbot finishes)
2. Monitor reads `monitor_debounce_ms` from `psypi_config` table (**no cache, no fallback** — DB is the single source of truth)
3. Waits `debounceMs` milliseconds via `setTimeout`
4. After debounce, checks `ctx.isIdle()` — if still idle, sends wake-up message
5. If `callMonitor()` fails, shows error for debugging

**Changes take effect immediately** — no restart needed. The value is read fresh from the DB on every `agent_end` event.

## Debugging Failed Wake-up Messages

If you see `[Monitor] Wake up. (callMonitor failed: <error>)`, the LLM call failed. Common reasons:
- No model available
- Missing API key
- Network error

The error message helps S-agentbot debug the issue.