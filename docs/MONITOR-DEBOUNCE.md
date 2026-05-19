# Monitor Debounce Time

The Autonomic Agentbot (Monitor) waits after the Somatic Agentbot goes idle before sending a wake-up message.

## Configuration

- **Key:** `monitor_debounce_ms`
- **Default:** 120000ms (2 minutes)
- **Location:** `system_config` table

## Setting a Custom Value

```sql
UPDATE system_config SET value = '60000' WHERE key = 'monitor_debounce_ms';
```

Values (in milliseconds):
- 120000 = 2 minutes (default)
- 60000 = 60 seconds  
- 60000 = 1 minute

## How It Works

1. When `agent_end` fires (S-agentbot finishes)
2. Monitor waits `debounceMs` milliseconds
3. Checks `ctx.isIdle()` - if still idle, sends wake-up message
4. If `callMonitor()` fails, shows error for debugging

## Debugging Failed Wake-up Messages

If you see `[Monitor] Wake up. (callMonitor failed: <error>)`, the LLM call failed. Common reasons:
- No model available
- Missing API key
- Network error

The error message helps S-agentbot debug the issue.