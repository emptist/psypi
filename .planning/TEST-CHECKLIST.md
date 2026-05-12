# Testing Checklist - psypi Identity System

## 1. Identity Computation

- [ ] `psypi-my-id` returns `S-psypi-psypi-unknown`
- [ ] `psypi-monitor-id` returns `A-psypi-psypi`
- [ ] IDs are computed fresh (no caching)

## 2. SOUL Lookup

- [ ] Worker SOUL loads: `S-psypi-psypi-unknown` → name="Worker", traits
- [ ] Monitor SOUL loads: `A-psypi-psypi` → name="Monitor", traits
- [ ] Different SOULs → different behaviors

## 3. System Prompt Injection (Experiment 1)

- [ ] Run `psypi`
- [ ] Send any message
- [ ] Look for `[MONITOR-INJECTED-...]` in Worker's response
- [ ] If visible → injection works

## 4. Notification Round-trip (Experiment 2)

```sql
INSERT INTO notifications (agent_id, priority, title, body)
VALUES ('S-psypi-psypi-unknown', 'high', 'Test', 'Check this!');
```
- [ ] Send message in psypi
- [ ] Worker sees notification in system prompt
- [ ] Worker acknowledges

## 5. Tool Blocked Protection

- [ ] Try `spawn pi` → should be blocked with hint
- [ ] Try `rm -rf /` → should be blocked with hint
- [ ] Normal tools NOT blocked

## 6. Event Hooks (Monitor/A- Mode)

- [ ] `session_start` fires → status shown
- [ ] `tool_result` on error → auto-files issue
- [ ] `before_agent_start` → reads notifications (after Experiment 1)

## 7. Build Verification

```bash
rm -rf build/ && gleam build
gleam run -m extension_generator
psypi
```

## Quick Test Commands

```bash
# Start psypi
psypi

# Inside psypi:
/psypi-my-id        # Should show S-psypi-psypi-unknown
/psypi-monitor-id  # Should show A-psypi-psypi
/psypi-tasks       # Should list tasks
/psypi-issues      # Should list issues
```

## Expected Outputs

| Command | Expected |
|---------|----------|
| `/psypi-my-id` | `{"id":"S-psypi-psypi-unknown",...}` |
| `/psypi-monitor-id` | `{"id":"A-psypi-psypi",...}` |
| `[MONITOR-INJECTED-...]` | Visible in response after running psypi |