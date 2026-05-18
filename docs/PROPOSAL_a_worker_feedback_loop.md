# Proposal: A-worker → S-worker Feedback Loop

## Problem

The A-worker sends wake-up messages to the S-worker via `pi.sendMessage()`, but never
hears back. It's a one-way, fire-and-forget channel. The A-worker keeps pinging on
every `agent_end` event, blind to whether the S-worker already responded, is busy, or
even saw the message.

This wastes LLM calls, burns context tokens, and creates noise in the session.

## Current Flow

```
A-worker (agent_end hook, setTimeout)
  → ctx.isIdle() check
  → callMonitor() — composes wake-up message (LLM call)
  → pi.sendMessage({ customType: 'autonomic-wakeup' }, { triggerTurn: true })
  → ...never hears back...

S-worker (next turn)
  → sees "[from A-worker:]" message
  → responds with analysis/reply
  → A-worker never sees this response
```

## Root Causes

1. **No reply channel** — `pi.sendMessage()` is one-way. No DB table, file, or
   in-memory mechanism for S-worker to deposit a response.
2. **No cooldown** — A-worker doesn't track when it last fired. No "last sent at"
   timestamp. Fires again on next `agent_end` even if S-worker already responded.
3. **S-worker reply goes to session, not to A-worker** — The S-worker's response is
   an assistant message in the session. A-worker has no mechanism to detect it.

## Proposals

### Option A — DB-backed reply channel (proper fix)

Create a table `autonomic_events`:

```sql
CREATE TABLE autonomic_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  direction   text NOT NULL CHECK (direction IN ('a_to_s', 's_to_a')),
  content     text NOT NULL,
  created_at  timestamptz DEFAULT now(),
  read_at     timestamptz
);
```

**Flow:**
1. On `agent_end`, A-worker writes `a_to_s` event with the wake-up content
2. S-worker (on its next turn) reads unread `a_to_s` entries, processes them,
   writes `s_to_a` reply
3. On next A-worker cycle, it reads `s_to_a` entries — if a reply exists that's
   younger than the last wake-up, skip new wake-up

**Pros:** Clean, persistent, survives restarts, auditable
**Cons:** New table, more complex, requires S-worker cooperation

### Option B — Session entry scanning (simpler, no schema change)

The A-worker already uses `ctx.sessionManager.getEntries()` for dedup. Extend this:

1. After sending wake-up, note the session entry ID
2. On next cycle, scan entries after that ID for assistant messages
3. If assistant reply found → S-worker responded, skip new wake-up
4. If no reply within timeout → send another wake-up

**Pros:** Zero schema changes, uses existing API
**Cons:** Heuristic-based, depends on session ordering, fragile

### Option C — Cooldown with `system_config` (minimal fix)

At minimum, prevent the endless ping loop. Track last wake-up in `system_config`:

```sql
UPDATE system_config
SET value = '<timestamp>', updated_at = now()
WHERE key = 'last_autonomic_wakeup';
```

Before sending: if last wake-up was within cooldown window (e.g. 5 min), skip.

**Pros:** Trivial to implement, uses existing table, eliminates the worst waste
**Cons:** Still one-way, just less frequent

## Recommendation

**Start with Option C** (cooldown) as an immediate fix — it's a one-line change in
`hook_agent_end_coordination.gleam` and stops the endless ping loop.

**Then implement Option A** (DB channel) as the proper long-term solution. This gives
the A-worker genuine awareness of S-worker responses and enables real two-way
communication.

Option B is a middle ground but too fragile for production use.

## Implementation Notes

- The cooldown check goes in `hook_agent_end_coordination.gleam` before the
  `setTimeout` — read `last_autonomic_wakeup` from `system_config`, compare to
  `now()`, skip if within window
- The DB channel requires changes in both `hook_agent_end_coordination.gleam`
  (A-worker writes `a_to_s`) and a new S-worker hook or tool (S-worker reads
  `a_to_s`, writes `s_to_a`)
- The `system_config` table already exists and stores `monitor_debounce_ms` —
  adding `last_autonomic_wakeup` is natural

## Related

- Pi extensions docs: `pi.sendMessage()` is confirmed one-way, no reply mechanism
- `sessionManager.getEntries()` API exists and is already used for dedup
- The Gleam migration (replacing fake generator files) is the right time to
  fix this — `hook_agent_end_coordination.gleam` is the natural place
