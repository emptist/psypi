# Monitor Debounce Time

The Autonomic Worker (Monitor) waits after the Somatic Worker goes idle before sending a wake-up message.

## Configuration

- **Key:** `monitor_debounce_ms`
- **Default:** 15000ms (15 seconds)
- **Location:** `system_config` table

## Setting a Custom Value

```sql
UPDATE system_config SET value = '60000' WHERE key = 'monitor_debounce_ms';
```

Values (in milliseconds):
- 15000 = 15 seconds (default)
- 60000 = 60 seconds  
- 120000 = 2 minutes (recommended for longer think time)

## How It Works

1. When `agent_end` fires (S-worker finishes)
2. Monitor waits `debounceMs` milliseconds
3. Checks `ctx.isIdle()` - if still idle, sends wake-up message
4. If `callMonitor()` fails, shows error for debugging

## Debugging Failed Wake-up Messages

If you see `[Monitor] Wake up. (callMonitor failed: <error>)`, the LLM call failed. Common reasons:
- No model available
- Missing API key
- Network error

The error message helps S-worker debug the issue.