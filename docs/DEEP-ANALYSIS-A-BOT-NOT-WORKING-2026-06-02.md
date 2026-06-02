# Deep Analysis — Why A-bot is "Not Working as Expected"

**Investigation date:** 2026-06-02
**Investigator:** AI agent (following the user's request to do a hard, evidence-based root-cause analysis)

---

## TL;DR — The Real Reason A-bot Appears Broken

A-bot **IS running successfully**. The LLM call works. The LLM produces coherent responses. The responses are saved to `psypi_config.last_wakeup` (visible in the database). The user sees A's responses in the conversation.

**But A's inter-review records are NEVER saved to the `inter_reviews` table**, and when the save fails, the error is **silently swallowed** and the message to S is sent with `triggerTurn: false` — meaning **S never gets a new turn** to act on A's findings.

Result: A keeps producing reviews that vanish into a black hole, and the alternating-current A→S hand-off is broken at the persistence layer.

**Three independent bugs in `inter_review.save()` must all be fixed for the inter-review loop to work:**

1. `requester_id` is `NOT NULL` in the schema but missing from the INSERT statement
2. `broadcast_review_finding` AFTER INSERT trigger references a `broadcasts` table that does not exist
3. `link_review_to_issue_auto` AFTER INSERT trigger tries to insert into `issues` without a `project_url` (which is `NOT NULL` in `issues`)

All three fail together because A's `inter_review.save()` is called with a hard-coded `score: 0`, and the triggers fire for `overall_score < 50`.

This analysis is **investigation only** — no fixes have been applied.

---

## Evidence

### Evidence 1: A-bot is running (DB confirms)

```
psypi_config.monitor_enabled       = "true"
psypi_config.monitor_debounce_ms   = "180000"        (3 minutes)
psypi_config.last_a_session_at     = 1780360958909   (recent ms timestamp)
psypi_config.last_wakeup           = "<1 KB coherent A response>"  (real text, not error)
event_hooks (psypi_event_hooks)    = agent_end: 453 successful triggers
```

`psypi_event_hooks` shows 453 successful `agent_end` runs (post-debounce). A's `last_wakeup` field contains a coherent paragraph, not an error string. The LLM call is working.

Reference: `psql -d psypi -c "SELECT key, value FROM psypi_config WHERE key IN ('last_a_session_at', 'last_wakeup', 'monitor_debounce_ms', 'monitor_enabled');"`

### Evidence 2: A's response is visible in the conversation

File `/Users/jk/gits/hub/tools_ai/psypi/src/A-bot-thinking.md` (683 lines) captures the live conversation. A's responses appear with the `[A-agentbot]` prefix, including:

```
[A-agentbot] Saving inter-review to database...

[A-agentbot]
I need to start by reading my soul and jobs from the database, then decide what to do.
<longcat_tool_call>call_monitor
<longcat_arg_key>query</longcat_arg_key>
<longcat_arg_value>SELECT soul FROM agent_soul WHERE agent = 'A';</longcat_arg_value>
</longcat_tool_call>
...
```

A's LLM is using the "monitor" persona, which has access to `call_monitor` (raw SQL/shell execution) and produces structured analysis.

### Evidence 3: `inter_reviews` table is empty of real A data

```
$ psql -d psypi -c "SELECT id, status, project_url FROM inter_reviews;"

                  id                  |   status   | project_url
--------------------------------------+------------+-------------
 df31f009-7f00-4b91-8eec-e6c1c832af24 | superseded |
 3c292699-597c-4f72-9646-097d21ba5829 | superseded |
(2 rows)
```

Only 2 seed/test records exist. Despite 453 successful `agent_end` runs, no A-driven inter-review has ever been persisted. (The columns `summary`, `findings`, `suggestions` are all `length=0` for the 2 superseded records.)

### Evidence 4: The save() function is missing `requester_id`

`/Users/jk/gits/hub/tools_ai/psypi/src/inter_review.gleam` (lines 38-69):

```gleam
pub fn save(
  summary: String,
  score: Int,
  findings: String,
  suggestions: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  let project_url = project_url()
  db.with_connection(
    fn(conn) {
      let sql = "
        INSERT INTO inter_reviews (project_url, status, summary, overall_score, findings, suggestions, completed_at)
        VALUES ($1, 'completed', $2, $3, $4::jsonb, $5::jsonb, NOW())
        RETURNING id
      "
      let params = [
        dynamic.string(project_url),
        dynamic.string(summary),
        dynamic.int(score),
        dynamic.string(findings),
        dynamic.string(suggestions),
      ]
      ...
```

The INSERT lists 7 columns: `project_url, status, summary, overall_score, findings, suggestions, completed_at`. The schema requires 8 NOT-NULL columns at minimum, including `requester_id`. The save() function never provides `requester_id`.

`psql -d psypi -c "\d inter_reviews"` shows:

```
     column_name      | is_nullable
----------------------+-------------
 id                   | NO
 requester_id         | NO     <-- MISSING IN INSERT
 ...
 project_url          | YES
```

This is **Bug #1** — the most obvious one. Every save attempt since the `requester_id` column was added (recent migration) has hit this NOT NULL violation.

### Evidence 5: The `broadcasts` table does not exist

```
$ psql -d psypi -c "SELECT tablename FROM pg_tables WHERE tablename LIKE '%broadcast%';"
 tablename
-----------
(0 rows)
```

The table that the `broadcast_review_finding` trigger inserts into was never created. The trigger was added with a phantom target. This is documented in the migrations:

```
src/migrations/028c_sql_errors_and_logic_bugs.sql:66
  'The send() function INSERT INTO project_communications ... has no status column.
   The list()/get_recent() functions hardcode ''sent'' as status alias.
   The BroadcastStatus type (Pending/Sent/Failed/Cancelled) is never written to or
   read from the database.'
src/migrations/027w_missing_type_inventory.sql:270
  'BroadcastStatus type maps to phantom status column that does not exist...'
```

**Bug #2** — the trigger `broadcast_review_finding` will throw `relation "broadcasts" does not exist` for any `overall_score < 50` insert.

### Evidence 6: Reproduced — score=0 fails, score=80 succeeds

Verified manually:

```sql
-- With score = 0 (what the code passes):
INSERT INTO inter_reviews (project_url, requester_id, status, summary,
                           overall_score, findings, suggestions, completed_at)
VALUES ('...', 'A-agentbot', 'completed', 'test with score 0', 0,
        '[]'::jsonb, '[]'::jsonb, NOW()) RETURNING id;
-- ERROR: relation "broadcasts" does not exist
-- CONTEXT: PL/pgSQL function broadcast_review_finding() line 5 at SQL statement

-- With score = 80:
INSERT INTO inter_reviews (project_url, requester_id, status, summary,
                           overall_score, findings, suggestions, completed_at)
VALUES ('...', 'A-agentbot', 'completed', 'test high score', 80,
        '[]'::jsonb, '[]'::jsonb, NOW()) RETURNING id;
-- OK
```

The `broadcast_review_finding` trigger condition is `IF NEW.overall_score < 50 OR NEW.code_quality_score < 50`. With `score = 0`, both are true. With `score = 80`, neither fires.

The hard-coded `0` in the call site (`/Users/jk/gits/hub/tools_ai/psypi/src/hook_on_agent_end.gleam:118`):

```gleam
inter_review.save(
  response,    // summary = LLM's full response text
  0,           // score = hardcoded to 0!
  "[]",        // findings = empty JSON array
  "[]",        // suggestions = empty JSON array
),
```

So **every** A inter-review attempt hits score=0 → triggers fire → save fails.

### Evidence 7: The 2nd trigger `link_review_to_issue_auto` would also fail

```sql
$ psql -d psypi -c "SELECT pg_get_functiondef(...) WHERE p.proname = 'link_review_to_issue_auto';"
```

```sql
CREATE OR REPLACE FUNCTION public.link_review_to_issue_auto()
RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
    IF NEW.overall_score < 50 AND OLD.overall_score IS NULL THEN
        INSERT INTO issues (
            title, description, issue_type, severity, created_by, review_id, metadata
        ) VALUES (
            'Review Finding: ' || COALESCE(NEW.summary, 'Low score review'),
            ...
            'bug',
            CASE WHEN NEW.overall_score < 30 THEN 'critical' ELSE 'high' END,
            'review-auto-create',
            NEW.id,
            jsonb_build_object(...)
        ) RETURNING id INTO NEW.issue_id;
    END IF;
    RETURN NEW;
END;
$function$;
```

This trigger also fires for `overall_score < 50`. It tries to insert into `issues` without `project_url`. Since `issues.project_url` is `NOT NULL`:

```
$ psql -d psypi -c "SELECT column_name, is_nullable FROM information_schema.columns
   WHERE table_name='issues' AND column_name='project_url';"
 project_url | NO
```

This trigger would fail with `null value in column "project_url" violates not-null constraint` if `broadcast_review_finding` were fixed first.

**Bug #3** — even after the broadcasts trigger is fixed, the issues trigger would still fail.

### Evidence 8: The save failure is silently swallowed

`/Users/jk/gits/hub/tools_ai/psypi/src/hook_on_agent_end.gleam:142-150`:

```gleam
Error(_) -> {
  pi_send_message(
    pi,
    "autonomic-wakeup",
    response,        // LLM's full text
    "persistent",    // display
    False,           // <-- triggerTurn: FALSE!
    "followUp",      // deliverAs
  )
}
```

When `inter_review.save()` fails (Error(_)), the code:

1. **Does NOT call `ctx_notify`** to tell the user
2. **Does NOT log the error** anywhere
3. **Sends the LLM's response to S with `triggerTurn: false`** — meaning the message is appended to the conversation but S does NOT get a new turn
4. **No follow-up happens** — S sees A's message in history but doesn't act on it

This is why A "looks broken" to the user: A says something useful, S doesn't react, the conversation goes quiet, and the user assumes A is malfunctioning.

This is a separate, **independent bug** — silent error swallowing combined with `triggerTurn: false` on the failure path.

### Evidence 9: The S path works fine (for comparison)

`/Users/jk/gits/hub/tools_ai/psypi/src/hook_on_before_agent_start.gleam` (28 lines total) is much simpler:

```gleam
pub fn on_before_agent_start() -> promise.Promise(Result(String, String)) {
  let trigger = promise.map(event_hooks.record_trigger("before_agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
  promise.await(trigger, fn(_) {
    promise.await(s_db_reader.read_s_soul_from_db(), fn(soul_result) {
      case soul_result {
        Ok(soul_content) -> promise.resolve(Ok(soul_content))
        Error(e) ->
          promise.resolve(Ok(
            "You are the Somatic Agentbot (S-agentbot)..." <> e,
          ))
      }
    })
  })
}
```

S's hook just reads the soul and returns it. No DB INSERT, no triggers, no score. The S path is clean and works. The A path has the inter-review persistence layer which is broken.

### Evidence 10: The `_hasWorked` flag is NOT the primary cause

`/tmp/extension.js` (generated from `extension_generator.gleam`):

```javascript
// Line 169
let _hasWorked = false;
// Line 206 (in agent_start)
pi.on('agent_start', async (_event, _ctx) => {
    _hasWorked = true;
    ...
});
// Line 172 (in agent_end)
pi.on('agent_end', async (event, ctx) => {
    try {
      if (!_hasWorked) { return; }       // <-- bail out if first event
      ...
      _debounceTimerId = setTimeout(async () => {
        _debounceTimerId = null;
        _hasWorked = false;
        try {
          const hook_on_agent_end_on_agent_end = (await import('./build/dev/javascript/psypi/hook_on_agent_end.mjs')).on_agent_end;
          ...
        }
      }, _debounceMs);
```

`event_hooks` shows:
- `agent_start`: 1403 triggers
- `agent_end`: 453 triggers (post-debounce count)

The `_hasWorked` race condition (first `agent_end` before any `agent_start` is dropped) is a **legitimate bug** but only causes 1 missed activation per extension load. After the first `agent_start` fires, every subsequent `agent_end` schedules the timer. The 453 successful `agent_end` runs prove this race condition has long since resolved.

The 1403 vs 453 ratio (~3:1) is consistent with normal A/S alternation: many S turns fire `agent_start`/`agent_end`, but the debounce timer is cancelled when S becomes active again before the 3-minute wait elapses. This is by design — see the project rule "A/S Dual-Agent Model — Debounce Timer Activation Logic" — and the `agent_end` count = number of times A actually ran.

### Evidence 11: The hooks do fire and log

The `last_wakeup` field has a coherent A response and the monitor alerts from the latest session show A is reading state, calling Monitor LLM, producing output. A is running. It's just that nothing it produces reaches the database or wakes S.

### Evidence 12: The HANDOVER-2026-06-01.md explained earlier issues

The 2026-06-01 handover documents the previous session's findings:

> A-bot was operating without its behavioral soul. The SQL query in `a_db_reader.read_soul_from_db()` only selected `role, domain, responsibility` from `agent_souls` — NOT the `content` column.

This was fixed in code (commit `dd5c675` "Fix A-bot soul loading + prompt builder issues"). And the conversation log proves A now reads its soul correctly:

```
psypi-my-id returned:
{"id":"S-psypi-...","responsibilities":"...","jobs":["1. [quality] CRITICAL: Never create pi_*.gleam modules..."]}

(and A's behavior is now driven by the loaded soul content)
```

So **the soul loading fix from the 2026-06-01 handover is working**. The current "A is not working" complaint is NOT about soul loading anymore. It's about the persistence layer and the triggerTurn failure path.

---

## Root Cause Hierarchy

### CRITICAL (Bugs that prevent the A/S loop from functioning)

**RC-1: `inter_review.save()` omits `requester_id`**
- File: `src/inter_review.gleam` (line 51)
- Impact: Every save attempt hits `null value in column "requester_id" violates not-null constraint`
- Even if other bugs are fixed, this one alone kills the save.

**RC-2: `broadcast_review_finding` trigger targets non-existent `broadcasts` table**
- File: defined in some migration, function body in pg_proc
- Impact: For `overall_score < 50`, the trigger throws `relation "broadcasts" does not exist`
- The trigger was created pointing to a phantom table that was never built.
- Known issue: documented in `src/migrations/027w_missing_type_inventory.sql`, `028c_sql_errors_and_logic_bugs.sql`, `029i_insert_audit.sql` (3 separate audits flagged the missing table).

**RC-3: `link_review_to_issue_auto` trigger omits `project_url`**
- Function body: `src/migrations/` (creator unknown, present in DB)
- Impact: For `overall_score < 50`, the trigger tries to insert into `issues` without `project_url`. Since `issues.project_url` is `NOT NULL`, this throws a NOT NULL violation.
- Bug #3 is hidden behind Bug #2 — once #2 is fixed, #3 surfaces.

**RC-4: Silent error swallowing on save failure with `triggerTurn: false`**
- File: `src/hook_on_agent_end.gleam` (lines 142-150)
- Impact: When save fails, A's response is sent to S with `triggerTurn: false`. S does NOT get a new turn. The PDCA loop silently dies.
- This is a **communication contract violation** combined with silent error handling.
- Documented as a separate issue: `51be7eff` "HIGH: pi_send_message used for internal thinking/errors — should use ctx_notify instead. Violates communication contract"

### HIGH (Bugs that are present but not the primary cause of the current symptom)

**RC-5: `inter_review.save()` always passes `score: 0`**
- File: `src/hook_on_agent_end.gleam` (line 119)
- Impact: This makes Bugs #2 and #3 fire on every save attempt. The score is a placeholder, not a real LLM-generated score.
- Even after fixing the triggers, the saved score would still be `0` (meaningless).

### LOW (Bugs in the extension.js generation that are present but secondary)

**RC-6: `_hasWorked` flag race condition on first event**
- File: `extension.js` (line 169, 172, 206)
- Impact: If the first event after extension load is `agent_end` (no prior `agent_start`), the hook exits early. After the first `agent_start`, this no longer matters. The 453 successful `agent_end` runs prove this has long since self-resolved.

### NON-ISSUES (Looked like bugs, but aren't)

- **Soul loading**: Fixed in commit `dd5c675`. The conversation log shows A now reads its full soul content. Working.
- **A-LLM using hallucinated SQL column names**: A's LLM does occasionally invent column names in its raw SQL calls. But that's a separate quality issue, not a "not working" issue. A still produces a coherent response even if some tool calls fail.
- **A's LLM using `psypi-tasks    ` (bare name, trailing spaces)**: A is using the Monitor persona with a different tool calling format (`<longcat_tool_call>call_monitor`). That's how the monitor LLM was prompted. Not a bug.

---

## Why A "Looks Broken" To the User

Putting it all together:

1. User asks something → S answers → S ends its turn → `agent_end` event fires
2. After 3 minutes of no further S activity → A's debounce timer fires
3. `hook_on_agent_end` runs → reads soul, jobs, S's recent session log, S's recent commits (NO project state — A is inter-review scoped, not whole-project scoped) → calls Monitor LLM via `call_monitor`
4. Monitor LLM produces a coherent response
5. A attempts to save the response to `inter_reviews` via `inter_review.save(response, 0, "[]", "[]")`
6. **The INSERT fails** — for the reasons in RC-1, RC-2, RC-3
7. The `Error(_)` branch fires (RC-4): A sends the LLM response to S with `triggerTurn: false`
8. The message appears in the conversation as `[A-agentbot] <response>`, but **S does not get a new turn**
9. Conversation goes silent
10. User sees A's message but no S response, and concludes "A is not working"

The user does not see the error. There is no `ctx_notify` for save failures. The A message is appended to history but S is not activated. The system looks dead.

---

## What Is Needed to Fix This (Investigation Only — No Fixes Applied)

For the A/S loop to function, the following must all happen:

1. **RC-1 fix**: Add `requester_id` to the INSERT in `inter_review.save()`. The function signature or call site must provide a value (e.g., `'A-agentbot'` or the A's actual ID).

2. **RC-2 fix**: Either create the `broadcasts` table, or drop/condition the `broadcast_review_finding` trigger. The "phantom broadcasts table" is a known issue across multiple audits.

3. **RC-3 fix**: Either add `project_url` to the trigger's INSERT, or drop the trigger, or set `project_url` to a sensible default. The trigger currently can't satisfy the NOT NULL constraint on `issues.project_url`.

4. **RC-4 fix**: On `inter_review.save()` failure, at minimum:
   - `ctx_notify(ctx, "[A-agentbot] <ERROR> inter-review save failed: " <> e, "error")` so the user sees the failure
   - Decide whether to still send `pi_send_message` with `triggerTurn: true` so S can react, or explicitly abort
   - Log the error to `system_reviews` or `review_findings` for traceability

5. **RC-5 fix**: Compute a real score (parse the LLM response, or default to a meaningful value like 50), and use that instead of hard-coded `0`. Otherwise the saved score is meaningless and Bug #2/#3 conditions stay active.

6. **Optional RC-6 fix**: Initialize `_hasWorked = true` to remove the first-event race condition. Low priority because it self-resolves after the first S turn.

These are the fixes. This report does not implement any of them — that is the next phase.

---

## What Was Not Investigated (Out of Scope for This Report)

- Why the LLM produces `<longcat_tool_call>` formatted tool calls (this is the Monitor persona's tool-calling convention)
- Why some of A's SQL queries use hallucinated column names (separate quality issue)
- Why `monitor_debounce_ms` is 180000ms (3 minutes) — this is a design choice, not a bug
- Why `last_wakeup` is updated by the wrong code path — the wakeup text IS visible, just not in `inter_reviews`
- The behavior of `command_listen.gleam` (the human-direct A path) — separate from the autonomous A path

---

## Files Referenced

- `src/hook_on_agent_end.gleam` — the A wake-up path
- `src/hook_on_agent_start.gleam` — agent_start handler
- `src/hook_on_before_agent_start.gleam` — S's soul injection path
- `src/inter_review.gleam` — broken `save()` function
- `src/pi_extension_ffi.mjs` — `call_monitor` FFI (works correctly)
- `src/pi_extension.gleam` — FFI declarations
- `src/a_db_reader.gleam` — A's soul/jobs reader (soul loading fixed in commit dd5c675)
- `src/a_prompt_builder.gleam` — A's prompt builder (truncation direction fixed)
- `src/psypi_config.gleam` — config reader including `get_debounce_ms`
- `/tmp/extension.js` — generated extension (regenerated during this investigation)
- `docs/HANDOVER-2026-06-01.md` — previous session's findings (soul loading)
- `docs/INVESTIGATION-A-BOT.md` — earlier investigation (debounce)
- `src/A-bot-thinking.md` — captured conversation log of A's actual behavior
- `src/migrations/008_agent_soul.sql` — A's soul content
- `src/migrations/027w_missing_type_inventory.sql`, `028c_sql_errors_and_logic_bugs.sql`, `029i_insert_audit.sql` — audits that already documented the `broadcasts` phantom table issue
