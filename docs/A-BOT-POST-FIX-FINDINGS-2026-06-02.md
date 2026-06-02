# A-bot Post-Fix Findings & Fix Plan — 2026-06-02

**Investigation date:** 2026-06-02
**Source:** Comparison of `docs/A-bot-thinking.md` (pre-`0f4d6ef`) vs `docs/conversation-log-after-0f4d6ef.md` (post-`0f4d6ef`), plus DB inspection of `inter_reviews` table.
**Status:** Investigation only. No fixes applied yet.

This document follows up on `DEEP-ANALYSIS-A-BOT-NOT-WORKING-2026-06-02.md`. The deep analysis identified 5 root causes (RC-1 through RC-5) and fixes were committed at `0f4d6ef`. This document captures **what the post-fix system actually does**, including new issues the deep analysis did not catch.

---

## TL;DR

The `0f4d6ef` fix worked. A's inter-reviews now land in `inter_reviews` with correct `requester_id`, `score`, and structure. S reads them and acts. The closed PDCA loop fires.

**But A is now showing 4 new behaviors that need attention.** None break the loop, but they pollute the data, produce redundant work, or expose model-quality issues. The most important is **Finding 1: A is re-reviewing the same content it already reviewed**.

**Core design problem across Findings 1, 2:** A is fed S's full session log every cycle, so A re-reviews the same content and hallucinates schema patterns it sees in the preloaded history. The fix is **NOT to cut off the context** (A is not an idiot; A can be told what to focus on and what to ignore). The fix is to give A clear instructions in its soul about scope and what-not-to-do, and let A figure it out. This is a 1-paragraph soul update + 1-line prompt header change. No DB slicing, no preloading, no JSON parsing, no boundary timestamps.

---

## Finding 1 — A's two reviews are 90% identical (DUPLICATION)

### Evidence

`inter_reviews` table contains 4 rows for this session (2 completed, 2 superseded). The two completed rows are:

| id | score | length |
|---|---|---|
| `facea97e-1fbb-4aa6-98e6-56218e38c5a9` | 4/10 | 13,710 chars |
| `92ebc2fc-e781-412f-8480-48702a6387f8` | 4/10 | 15,954 chars |

Diffed the `summary` columns directly. The only material difference is **one new finding** in the second review ("S accepted A's inter-review without pushback") plus a re-ordered presentation. Everything else — pwd failure, imprecise PDCA, find /, memory saves, doc reading, honesty — appears in both reviews with near-identical wording.

### What happened between the two reviews

Reading `docs/conversation-log-after-0f4d6ef.md` lines 690–776: S did **NOT** do any new tool work, write any code, or commit anything between the two reviews. S only:
1. Read A's first review (facea97e)
2. Acknowledged each finding ("Confirmed. I will…")
3. Made commitments for the next session

That is the entire Act phase. ~80 lines of conversation, no observable S work product. Yet A produced a full 15.9 KB inter-review covering all the same behavior, plus one meta-finding about S's acceptance.

### Root cause

A's prompt in `src/a_prompt_builder.gleam` includes S's full session log (entries_json). It does **not** include:
- A "review boundary" marker (where the previous review ended, where the new content begins)
- A's previous review findings/score
- A directive to focus on the delta

So A sees S's full conversation history, treats it as fresh content, and re-reports the same findings. The model is doing exactly what an unbounded-context LLM does: re-narrate what it sees.

### Why this matters

1. **Redundant work.** Two inter-reviews cost two LLM calls and two DB rows. The second carries almost no new information.
2. **Score pollution.** Both reviews score S 4/10. If a future system review averages scores per cycle, the same failure gets counted twice.
3. **False narrative.** It looks like S was reviewed on two separate "cycles" of work, but in fact there was one cycle of work and one cycle of S-acknowledging-A.
4. **Hallucination enabler.** When A sees a prior review's `[inter-review id: facea97e-...]` text in the preloaded session log, A imitates the schema and invents a new ID — see Finding 2.

### Fix plan (minimal — trust A to follow instructions)

The original plan sliced the data. The user pointed out that A is not an idiot — give A the rules, not pre-filtered data. The minimal fix is a **soul update + a prompt section header change**. No code logic, no DB queries, no JSON parsing.

**F1.1 — Update A's soul with scope rules.**
Add to `agent_souls` for `id_prefix='A'`:

> "**Inter-review scope (revised 2026-06-02):** My inter-review covers the LATEST CYCLE of S-bot's work, not the whole session. The full session log is provided in my user_prompt for context, but I focus my findings on what S did in the most recent activity. Anything older than the most recent cycle was already reviewed in a previous inter-review. I do not re-list findings from prior reviews. I use prior context only to detect deviations: if S committed to do X in a prior review and did Y instead, that is a finding. Otherwise, the prior context is reference material, not review material. If S did nothing new in the latest cycle, my review is a short 'no new findings' note. I do not pad it with re-narration of the whole session."

**F1.2 — Update the prompt section header.**
In `src/a_prompt_builder.gleam::build_user_prompt`, change:

```
"## S-bot's Recent Conversation (most recent at the end):\n"
```

to:

```
"## S-bot's Conversation (most recent at the end):\n"
"<A small note: focus on the latest activity in this log. The full log is for context; do not re-review what was already covered in a prior inter-review.>\n"
```

That's the entire fix for Finding 1. Two text changes, no logic.

**F1.3 — Idempotency guard (optional, defer).**
If the soul + prompt fix doesn't take effect after a real session, add a DB-level check in `inter_review.save()`: if the new review's content similarity to the previous one is > 85%, save with `status='superseded'`. This is a safety net, not the primary fix. Defer until we see real evidence that F1.1 + F1.2 are insufficient.

### Verification

Run a fresh S session, let A produce a second review, and confirm:
- The two reviews share < 30% content overlap (was 90%)
- The second review's Key Events section covers only the activity after the first review (e.g. S reading A's review and acknowledging)
- The new review contains at most 1 carry-over reference (a "no new findings" or "still ongoing" note), not 7 re-listed findings
- A did not re-state the same finding with new wording

---

## Finding 2 — A hallucinated a review ID in the second review (REGRESSION)

### Evidence

Query the saved `summary` for `92ebc2fc-e781-412f-8480-48702a6387f8`. The last 70 characters are:

```
[inter-review id: b8e3f2c1-7d4a-4e9b-8f3a-2c1d4e5f6a7b]
```

This ID **does not exist** in `inter_reviews`. The actual ID is `92ebc2fc-...`. The real ID is appended by the hook **only to the `pi.sendMessage` content** (so the S-bound message ends with `[inter-review id: 92ebc2fc-...]`), but the DB's `summary` column stores A's raw response — which contains the fake ID.

The first review (`facea97e`) does **not** have this problem. It contains no fake ID. A's response is plain text; the hook appends the real ID at the end of the S-message and the DB only has the response without an ID.

### Why the second review is different

A's second prompt includes the full session log, which now contains the first review's text (with its hook-appended `[inter-review id: facea97e-...]` at the end). A saw the schema and imitated it, inventing a UUID. A does not know what ID the hook will assign it — so A makes one up.

This is the **same hallucination class as the old `<longcat_tool_call>` problem** that migration 038 fixed. The fix at that time forbade tool-call XML. It did not address schema-pattern completion in general.

### Why this matters

1. **DB inconsistency.** `inter_reviews.summary` for `92ebc2fc` ends with a fake UUID. If anyone greps for that ID in the DB, they find a row, but the ID in the row's `id` column is different. Confusing.
2. **Schema leakage.** A is reaching into the hook's responsibility (assigning IDs). A should output plain text and let the hook do its job.
3. **Trust erosion.** Every artifact A produces must be independently verified if A can hallucinate its own metadata.

### Fix plan

**F2.1 — Update A's soul to forbid the schema.**
The soul update in F1.1 already addresses scope. Add a second rule to the same soul update:

> "**Schema discipline (revised 2026-06-02):** I never emit any string matching the pattern `[inter-review id: <uuid>]` or `[review id: ...]` or any other ID format. The hook appends the canonical ID at the end of the S-bound message. If I see myself about to write such a string, I STOP and remove it."

**F2.2 — Strip hallucinated IDs from A's response.**
Unchanged from the original plan. In `src/hook_on_agent_end.gleam::on_agent_end`, before saving to DB or sending to S, scan A's response for any pattern matching `[inter-review id: <uuid>]` or `[review id: <uuid>]` and strip it. Then the hook appends the canonical ID.

This is defense-in-depth in case the soul update doesn't fully take effect. The user's point — "A is not an idiot" — means F2.1 should be enough, but F2.2 is a cheap, low-risk safety net.

**F2.3 — Detect and report the strip.**
Unchanged. If the hook strips a hallucinated ID, log a `ctx.ui.notify()` with the message "A hallucinated a review ID, stripped before save".

### Verification

Run a fresh S session. Confirm:
- A's response text in `inter_reviews.summary` never contains `[inter-review id: <uuid>]`
- The S-bound message ends with exactly one `[inter-review id: <canonical-id>]` (the hook-appended one)
- A new "hallucinated ID stripped" notification appears in `last_wakeup`/logs (proving the strip fired)

---

## Finding 3 — Double `[A-agentbot]` prefix in the conversation log (UI DISPLAY)

### Evidence

`docs/conversation-log-after-0f4d6ef.md` shows the following pattern at lines 611 and 782:

```
[A-agentbot] [A-agentbot]

Let me analyze what happened in this S session and produce my inter-review.
```

A's response in the DB starts with `\n\n` (blank line, then text). The hook's `string.starts_with(response, "[A-agentbot]")` check should return `False` (because the actual first character is `\n`), so the hook correctly adds the prefix once. The result going to S should be `[A-agentbot] \n\nLet me analyze…` — single prefix.

But the conversation log shows two. So something between the hook and the displayed log is adding a second `[A-agentbot]`.

### Possible causes

1. **Pi UI display layer** automatically prefixes the agent's name when `customType: "autonomic-wakeup"` is used in `pi.sendMessage`. The hook prefixes for the message body; Pi prefixes for the display. Both prefixes show in the log.
2. **The hook is calling `pi.sendMessage` twice** with the same content (unlikely — would also be visible in other A messages).
3. **`ctx.ui.notify` and `pi.sendMessage` are both adding the prefix** for status messages.

### Why this matters

Cosmetic. The actual content delivered to S has one prefix; the log shows two. But it makes the log harder to grep and is a sign of unclear responsibility between Pi and the hook for message formatting.

### Fix plan

**F3.1 — Investigate.**
Add a temporary debug log in the hook to print the exact content passed to `pi.sendMessage`. Compare to what appears in the conversation log. Identify which layer is adding the second prefix.

**F3.2 — Single-source the prefix.**
Once the source is identified, fix it. If Pi UI auto-prefixes for `customType: "autonomic-wakeup"`, stop adding the prefix in the hook for that customType. If the hook is double-prefixing, fix the hook.

### Verification

After fix, the conversation log should show exactly one `[A-agentbot]` prefix on A's review messages.

---

## Finding 4 — A's "Calling monitor..." fires while user is active (RACE CONDITION)

### Evidence

`docs/conversation-log-after-0f4d6ef.md` line 540:

```
... human message ...

[A-agentbot] Calling monitor...

... more human input AFTER this ...
```

A's monitor call started while the human was still mid-typing. The debounce timer should have been cleared on `input` events, but the log shows the monitor call started first.

### Why this matters

Lower priority. The hook's async `call_monitor` will complete and send a review even if the user has typed something in the meantime. The review may be slightly stale by the time it arrives. The current design accepts this race.

The risk: in a fast-moving conversation, A could send a review based on prompt data from 30 seconds ago, by which time S has done 3 more things. The review becomes irrelevant quickly.

### Fix plan

**F4.1 — Capture a snapshot of the user-activity timestamp at the moment the debounce fires.**
When the timer expires, record `now_ms()`. If a new `input` or `agent_start` event has occurred between the timer firing and the LLM result arriving, abort the LLM call (or discard its result) instead of sending the review.

**F4.2 — Optional: cancel the in-flight LLM call.**
If Pi's LLM call is cancellable, cancel it on user activity. Otherwise, just discard the result and let the next debounce cycle do a fresh review.

### Verification

In a fast-moving conversation, A's reviews should reflect S's most recent state, not state from 30+ seconds ago.

---

## Cross-cutting fix: testing

Add tests for:
- `inter_review.save()` rejects content similar to the previous review (F1.4)
- Hook strips hallucinated IDs (F2.2)
- A's prompt contains the review boundary marker (F1.1)
- A's prompt contains the previous review summary (F1.2)

---

## Implementation order

The minimal plan is just two text changes. Suggested order (lowest risk first):
1. **F1.1** — soul update for scope (zero risk, takes effect on next cycle)
2. **F2.1** — extend the soul update to forbid ID strings (zero risk)
3. **F1.2** — prompt section header change (zero risk, takes effect on next cycle)
4. **F2.2** — hook defense: strip hallucinated IDs (small risk, run side-by-side)
5. **F2.3** — log when strip fires (negligible risk)
6. **F1.3** — DB-level idempotency (defer until we've seen F1.1+F1.2 in action)
7. **F3.1** — investigate the double prefix (no code change yet, just add debug logging)
8. **F4.1, F4.2** — race condition fix (architecture change, careful work)

After each fix, run a real S session and verify the corresponding Finding is gone.

---

## Out of scope

- A's review of S's behavior quality (Finding 1's content is correct; only the duplication is the issue)
- S's `pwd`-first discipline (model quality, per user's earlier statement: "we don't care about what S does, that is the problem of model quality")
- The PDCA loop architecture itself (working as designed)

---

## References

- `docs/DEEP-ANALYSIS-A-BOT-NOT-WORKING-2026-06-02.md` — the previous analysis whose fixes are being verified here
- `docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md` — A's architecture (no tools, text-only LLM). See § [Conversational Frame](./DESIGN-A-BOT-NO-TOOLS-2026-06-02.md#conversational-frame-added-2026-06-02-after-user-feedback) for the framing refined after this analysis.
- `docs/A-bot-thinking.md` — pre-fix conversation log
- `docs/conversation-log-after-0f4d6ef.md` — post-fix conversation log
- `src/hook_on_agent_end.gleam` — A's hook callback
- `src/a_prompt_builder.gleam` — A's prompt builder
- `src/agent_souls` table — A's soul content
