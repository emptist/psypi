# Handover Memo — 2026-06-03 (soul reorder + long-text issue + job-table sync)

## TL;DR

Six commits shipped in this session. The A bot's "Conversational Frame"
section moved from position 20 (end of soul) to position 9 (right after
"Communication"). Issue 045 documents the underlying design principle
that motivated the workflow: long-text fields should be normalized to
child rows. The AGENTS.md job tables were re-synced with the live DB
(A=24, S=20). This handover memo is the 6th commit.

**The session ended with two open strategic questions, not implementation
tasks.** Both are below as "Key insight" sections:

1. **The A/S loop is a conversation, not a process** (the
   "Conversational Frame" reframing — `inter_reviews` is a chat log).
2. **The DB tables should be append-only, not update-in-place**
   (the user's late-session realization — `inter_reviews` already does
   this; `agent_souls` and `agent_jobs` don't, and that's a real data
   loss risk; 3 options to choose from are in the next session's
   decision queue).

**The user has explicitly said: do NOT try to finish anything in the
next session. Open both questions as discussions, present options,
let the user choose.**

## ⭐ Key insight (read this first, even before the rest of this doc)

**The most valuable thing from this session is NOT the soul reorder or
the long-text issue. It is the realization that the A/S loop is a
conversation, not a process pipeline.** This reframing was the
intellectual center of the whole session's work.

### What "Conversational Frame" means (one-paragraph version)

A is a **chat participant** in an ongoing dialogue with S, not a
reviewer filling in a form. The "inter-review" is just A's **turn to
speak** in the PDCA cycle. The `inter_reviews` table is a chat log,
not a review submission. Schema correctness (no fake IDs, no fake
UUIDs, the hook owns ID assignment) is still required — that is
**correctness, not format**. There is no rigid "summary / score /
findings / next steps" structure A must follow. A is free to ask S
questions in the same message as observations; the back-and-forth is
the loop, not a handoff document.

### The 锵锵三人行 / 圆桌派 analogy

- **A** = 窦文涛 (the host / round-table moderator). Does not argue
  the cases himself; draws the cases out of the guests. A's job is to
  keep the conversation moving, ask the awkward question, surface
  what S has not yet explained.
- **S** = the work-guest. Brings the substance, does the tool work,
  answers A's questions.
- **The optional human** = the second guest. Can intervene, but the
  show runs without them. ("The human is not in the loop" is the
  default posture; see the `self_monitor` jobs in A's job list.)

A doesn't "hand off" to S — A *uses* S, the way 窦文涛 uses his guests.
The PDCA cycle is the **rhythm** of the conversation, not its
substance. S is not waiting for a formal review submission; S is
waiting for A to talk.

### Where this lives in the codebase

| Layer                         | Location                                                            | Status                                               |
| ----------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------- |
| A's soul                      | `agent_souls` table, **§9 "Conversational Frame"**                  | ✅ active, reordered in this session (commit b518bd4) |
| Design rationale              | `docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md` § "Conversational Frame" | ✅ finalized                                          |
| Plan/findings that led to it  | `docs/A-CONVERSATIONAL-FRAME-FINDINGS-2026-06-02.md`                | ✅ filed                                              |
| Follow-up findings (post-fix) | `docs/A-BOT-POST-FIX-FINDINGS-2026-06-02.md`                        | ⚠️ 4 new behaviors flagged; de-duplication still open |
| Prompt builder                | `src/command_listen.gleam` `build_user_prompt`                      | ✅ "no rigid format" language applied                 |

### Why this matters for the next session

1. **Don't re-litigate.** If a future reviewer (or future-A in a
   future session) suggests re-adding "summary / score / findings /
   next steps" format prescriptions, push back with the analogy. The
   user is on record that the dialog-first framing is the correct one.
2. **When you write code that touches A's output, the rule is
   schema-correct, not format-rigid.** Examples: the hook's
   hallucinated-ID strip is a correctness rule, not a format rule.
   `parse_review_score` defaults to 50 if absent — score is flavor,
   not the point.
3. **The `inter_reviews` table is a chat log, not a review form.** If
   someone proposes to add `findings_json` or `next_steps_required`
   columns, ask first whether the proposed constraint is for
   *correctness* or for *form*. Only correctness constraints belong
   in the schema.
4. **If a behavior looks "off" in A's reviews, the most likely cause
   is re-reviewing the same content** (see Finding 1 in the post-fix
   doc), not A reverting to the formal-reviewer framing. Don't fix
   the framing; fix the scope.

## ⭐ Key insight #2: append-only, not update-in-place (CRITICAL, NEW at end-of-session)

**The schema design issue is a pseudo-problem. The real problem is
improper use. The right pattern is: add new records — when you save,
you create a new record. Don't modify records.**

This was the user's second major insight of the session, and it
**changes the design direction** that issue 045 implied. Read this
section before doing anything with `agent_souls` or `agent_jobs`.

### Direct user quotes (verbatim — do not paraphrase further)

These are the user's exact words from this session. Preserved
verbatim so the next session does not have to recover intent from
paraphrase.

> "如果数据库是唯一资料来源，而里面的资料没有历史记录，那就太可怕了"
>
> — the user, just before articulating the append-only insight.
> This is the trigger: data loss in the only source of truth is
> unacceptable.

> "我意识到数据库的表设计这个问题是一个伪问题，真实问题是你使用不当。应该是加入新记录，保存就记录，你变成修改记录"
>
> — the user, articulating the append-only insight. The "你变成
> 修改记录" phrasing is slightly ambiguous in Chinese; the meaning
> the user confirmed in follow-up is "the save operation IS the
> new modification record" — i.e., INSERT, never UPDATE.

> "首先不要再考虑在当前会话完成什么东西。必须交班。"
>
> — the user, end of session. The directive: write the handover,
> do not implement.

### The 3-table pattern audit

We already have proof that the right pattern works in psypi:

| Table           | Current pattern          | Is append-only? | What it means for history        |
| --------------- | ------------------------ | --------------- | -------------------------------- |
| `inter_reviews` | INSERT only, 25 rows     | ✅ yes           | Every A review is a new row      |
| `agent_souls`   | UPDATE in place, 2 rows  | ❌ no            | Old content lost on every save   |
| `agent_jobs`    | UPDATE in place, 44 rows | ❌ no            | Old job description lost on edit |

`inter_reviews` is the canonical example: 25 rows, one per review,
no `is_active` flag, no UPDATE. The "current" review is determined by
`MAX(requested_at)` (or by `id`). It naturally has full history for
free — that is the "chat log, not review form" property the
Conversational Frame insight relies on.

`agent_souls` and `agent_jobs` violate this. The `is_active` flag was
designed for "multiple rows, one active" semantics, but the actual
usage is "one row, UPDATE in place" — the flag is a lie.

### What the right pattern looks like for `agent_souls`

- Keep `is_active` (the flag itself is fine — it's a "current pointer")
- Keep UNIQUE on `id_prefix` but **change the constraint to partial**:
  only one row per `id_prefix` may have `is_active = true` (use a
  partial unique index instead of a plain UNIQUE on `id_prefix`)
- "Save a new soul" = single transaction:
  1. `INSERT INTO agent_souls (..., is_active=true) RETURNING id`
  2. `UPDATE agent_souls SET is_active = false WHERE id_prefix = X AND id != new_id AND is_active = true`
- The old rows stay in the table forever. History is a free
  byproduct of correct usage.
- A reader query `WHERE id_prefix='A' AND is_active=true` keeps
  working — no read-path changes.

### Chain reaction: what else changes

1. **Existing migrations 044, 045 are wrong** in light of this
   insight. They used `UPDATE ... SET content = ...`, which destroyed
   the previous content. The "previous content" we lost: the soul as
   it was at `updated_at = 2026-05-30 11:05:32.378119+08` (A's
   pre-reorder state). We have no snapshot of it. Going forward, the
   append-only rule prevents this kind of loss.
2. **`agent_jobs` has the same problem.** Each of the 24+20 job
   descriptions is a one-time `INSERT` and then never updated (in
   practice). But the schema permits UPDATE, and any future code path
   that does `UPDATE agent_jobs SET job='...' WHERE id=...` loses
   history. Same fix applies.
3. **Seed files (`seed.gleam`, `008_agent_soul.sql`) need to encode
   history, not just the current state.** The first fresh install of
   psypi after this change should replay ALL historical versions, not
   just the latest. The latest becomes `is_active = true`; the older
   ones are `is_active = false` history rows.
4. **Issue 045's normalization direction (long-text → child rows)
   becomes partially moot.** If `agent_souls.content` is append-only
   and each "save" is a new row, you can still edit a "section" by
   INSERTing a new full soul — not as cheap as editing one row in
   `agent_soul_sections`, but the history is free. The child-row
   design is still nicer for editing, but it's not a data-loss fix
   anymore — the append-only rule is.
5. **Gleam code paths that write to `agent_souls` need to be
   audited.** Find every `UPDATE agent_souls ...` and wrap it in a
   transaction that INSERTs a new row first. This is a real code
   change, not a schema-only change. Likely 2-5 sites in
   `src/pi_extension_*.gleam` and `src/migrate*.gleam`.

### What to do next — 3 options

The user has not yet picked one. Present these to them in the new
session:

- **Option A: Implement now.** Migration 046 = (a) drop UNIQUE
  constraint on `id_prefix`, replace with partial unique index on
  `(id_prefix) WHERE is_active = true`; (b) snapshot current A and S
  as `is_active = false` history rows (so we don't lose the
  pre-044 / pre-045 state retroactively); (c) create a
  `save_soul_version(content, change_reason)` SQL function as the
  one blessed writer. Then change 044, 045 to use it. Then audit
  Gleam code paths. **Estimated: 2-3 hours, multi-commit.**
- **Option B: Document-only invariant.** Add a section to AGENTS.md
  saying "soul changes must INSERT, not UPDATE" and let the
  convention catch on. **Cheap but unreliable** — relies on humans
  (and AIs) reading the doc. Catches zero of the existing wrong
  code paths.
- **Option C: A-S meeting first.** psypi-meeting-add topic:
  "Should `agent_souls` and `agent_jobs` go append-only? What is the
  impact on migrations 044, 045, the seed files, the Gleam write
  paths, and issue 045?" Let A and S discuss scope before
  committing to A or B. **Recommended — large surface, many
  decisions, the user historically prefers alignment over speed.**

### Why this matters for the next session

1. **Don't repeat the mistake.** Any future soul/job change done with
   `UPDATE ... SET ...` continues to destroy history. Even if Option
   C is chosen and no migration lands this week, every soul/job
   write from this point on should mentally be "INSERT a new version,
   deactivate the old one" — even if the SQL is still `UPDATE`. Treat
   it as a discipline, not just a schema choice.
2. **Issue 045 is now in tension with this insight.** 045 said
   "normalize long-text fields to child rows". That is still a
   reasonable ergonomic improvement, but the data-loss argument is
   weakened. If the next session is told "do issue 045", pause and
   re-confirm with the user — does the user still want the
   normalization, or is append-only enough?
3. **The de-dup problem (Finding 1 in A-BOT-POST-FIX-FINDINGS) is
   separate.** Re-reviewing the same content is a *prompt/context*
   problem, not a *schema* problem. Append-only doesn't fix it.
4. **The 3-table pattern audit is the new "design review checklist"
   for any future psypi table.** Before creating a new mutable table,
   ask: "Could this be append-only with a `is_active` pointer?" If
   yes, do it that way. The `inter_reviews` table is the model.

## What happened (6 commits, in order)

```
49690cf docs: HANDOVER-2026-06-03-soul-reorder.md (with job-table sync follow-up)
62cc862 AGENTS.md: re-sync the A/S job tables with the live DB (2026-06-03)
1bb89fd issue: open table design principle — avoid long-text fields, normalize to child rows
d31f2f3 seed: sync A soul canonical seeds with the new reordered content
b518bd4 A: soul — reorder Conversational Frame to §9 (right after Communication)
44901b6 docs(a/s-roles): rename S role from "PDCA Do" to "PDA with a bit self-C"
```

### 44901b6 — PDA self-C rename (3 files)

Renamed S's role from "PDCA Do" to "PDA with a bit self-C" because S
does plan/do/act plus a bit of self-check; the formal Check is A's job.
Touched `AGENTS.md`, `009_agent_jobs.sql`, `037_clarify_agent_roles.sql`.

### b518bd4 — Migration 044: soul reorder

New file `src/migrations/044_a_soul_reorder_conversational_frame.sql`.
Uses a full `UPDATE agent_souls SET content = $$ ... $$` (dollar-quoted)
to replace A's entire soul with the reordered version. Idempotent.

The new section order puts **Conversational Frame** immediately after
**Communication** so the framing shapes the very mechanism it describes
(`pi.sendMessage` with `triggerTurn: true`).

Heading renamed to `## Conversational Frame (added 2026-06-02)` to match
the suffix style used by Schema Discipline / Scope / Two Modes.

### d31f2f3 — seed sync (2 files)

`src/seed.gleam` and `src/migrations/008_agent_soul.sql` updated to
match the new DB state. Both files MUST stay byte-identical to live DB
for fresh-install + migration reproducibility.

### 1bb89fd — Migration 045: open issue (1 file)

New file `src/migrations/045_issue_table_design_long_text.sql`. Inserts
a new `issues` row documenting the principle:

> Long-text fields (a single TEXT column holding a multi-page markdown
> blob) are a design smell when the content is structurally sectioned.
> They make every edit expensive, fragile, and error-prone.

Idempotent via `WHERE NOT EXISTS`. Verified — running twice gives
INSERT 0 1 then INSERT 0 0.

**Issue ID**: `dbb06944-b296-41d6-ad77-c930ebba1cda`
**Status**: open / medium / improvement
**Tags**: schema-design, principle, long-text, normalization, preventive

### 62cc862 — AGENTS.md job-table sync (1 file)

Re-synced the A and S job tables in AGENTS.md with the live DB. The
previous snapshot showed 12 of A's 24 jobs and 14 of S's 20 jobs.

- Both tables now show ALL active jobs in priority+category order
- Header counts: A=24, S=20
- A heading reads "PDCA Check" (A is the formal Checker, not PDA self-C)
- S heading reads "PDA self-C" (matches commit 44901b6 role framing)
- Added a "Known doc/DB drift" note flagging the A self_monitor
  near-duplicate. The older one (`d9d45795-...`, "Do NOT wait for the
  human") was superseded by `450a12db-...` ("The human is not in the
  loop"). NOT fixed here — tracked for a follow-up migration.

### 49690cf — This handover memo (1 file)

The doc you are reading. Created at end-of-session as a fresh-start
guide for the next conversation. Lists what shipped, what state the
DB/code are in, the workflow that worked, and the 4 open follow-ups
in priority order.

## Current state

- **DB**:
  - A's soul has Conversational Frame in §9 (after Communication, before Values)
  - Issue 045 is open in `issues` table
  - 2 active self_monitor rows at A priority 1 (one superseded; see follow-up #1)
- **Code**:
  - 6 commits on `a-s-flow` branch, including 2 new migrations (044, 045)
  - `seed.gleam` + `008_agent_soul.sql` in sync with DB
  - AGENTS.md job table in sync with DB (A=24, S=20)
  - `gleam test` → 98 passed, no failures
- **Branch**: `a-s-flow` (6 commits ahead of `develop`)
- **Working tree**: clean (only untracked `docs/conversation-log-after-89f00d4.md`,
  user said leave it for now)

## Files to know

| Path                                                         | Why it matters                                                  |
| ------------------------------------------------------------ | --------------------------------------------------------------- |
| `src/migrations/044_a_soul_reorder_conversational_frame.sql` | The reorder — A's soul definition lives here                    |
| `src/migrations/045_issue_table_design_long_text.sql`        | Issue record (the principle)                                    |
| `src/seed.gleam`                                             | First-run seed (must match DB)                                  |
| `src/migrations/008_agent_soul.sql`                          | Canonical seed (must match DB)                                  |
| `src/migrations/009_agent_jobs.sql`                          | Canonical seed for A/S job list                                 |
| `src/migrations/037_clarify_agent_roles.sql`                 | Enforces "S never does system-review" etc.                      |
| `AGENTS.md`                                                  | Read first when starting a new session                          |
| `docs/A-CONVERSATIONAL-FRAME-FINDINGS-2026-06-02.md`         | The thinking behind the Conversational Frame                    |
| `docs/A-BOT-POST-FIX-FINDINGS-2026-06-02.md`                 | 4 new behaviors after the 0f4d6ef fix; de-dup still open        |
| `docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md`                   | Design rationale for text-only A + the § "Conversational Frame" |
| `docs/HANDOVER-2026-06-03-soul-reorder.md`                   | This file (you are here)                                        |

## Workflow that worked (for future soul edits)

1. Extract DB content to a temp file:
   ```sql
   psql -d psypi -tA -c "SELECT content FROM agent_souls WHERE id_prefix='A'" > /tmp/a_soul.md
   ```
2. Edit the temp file in plain text.
3. Build a migration using dollar-quoted SQL to embed the new content:
   ```sql
   UPDATE agent_souls SET content = $$ <new content> $$ WHERE id_prefix='A';
   ```
4. Run via `psql -d psypi -f <migration>.sql`. Dollar-quoting handles
   embedded apostrophes and newlines without escaping.
5. Sync `seed.gleam` and `008_agent_soul.sql` (Gleam string escaping:
   `\\` → `\\\\` for backslashes, `"` → `\"` for double quotes, `'` → `''`
   for SQL).
6. Verify with `gleam test`.

## Known minor issue (NOT a bug, cosmetic only)

DB content has a trailing `\n\n` (2 newlines) at the end of the soul,
but `seed.gleam` and `008_agent_soul.sql` have `\n\n\n` (3 newlines).
The `simple_migrate.gleam` runner adds an extra newline when echoing
content. Semantic identity preserved, but byte-level diff has 1 line
of difference. Not worth a fix unless we ever move to a content-hash
reproducibility check.

## What's next (open follow-ups, in priority order)

**🚨 Highest priority — discuss with user FIRST before any work:**

0. **The append-only decision (Key insight #2).** This is the
   elephant in the room. Three options on the table (A: implement
   now / B: docs only / C: A-S meeting). **The user's most recent
   message in this session was: "首先不要再考虑在当前会话完成什么东西。
   必须交班。"** — i.e., do NOT try to finish this in the next
   session either. Open it as a discussion, present the 3 options,
   let the user choose. This is a "do not act, ask first" item.

1. **Deactivate superseded A self_monitor job** (small follow-up,
   safe to do independently of the above):
   `d9d45795-2c85-461c-9861-9498c355ef20` ("Do NOT wait for the human")
   was superseded by `450a12db-787d-4685-9c31-973fbdf1e990` ("The human
   is not in the loop"). Migration 046 (or 047 if append-only lands
   first) should `UPDATE agent_jobs SET is_active = false WHERE id =
   'd9d45795-...'`. After that, AGENTS.md "Known doc/DB drift" note
   can be removed. Estimated: 5 min.

2. **conversation-log cleanup**: Add `docs/conversation-log-*.md` to
   `.gitignore` so they don't show as untracked. Or move to
   `docs/archive/sessions/`. Estimated: 2 min.

3. **Long-text issue sub-tasks** (from issue 045 description):
   Refactor `agent_souls.content` into
   `agent_soul_sections (id, soul_id, ordering, heading, body)` so
   reordering a section is one `UPDATE` instead of a full content
   replace. **PAUSE and re-confirm with the user** — see Key insight
   #2 above. The data-loss motivation is weakened once append-only
   is adopted; only the ergonomics argument remains.

4. **AGENTS.md job table update**: ✅ DONE in commit 62cc862. The job
   table is now in sync with the live DB (A=24, S=20). The
   "Known doc/DB drift" note flags the A self_monitor near-duplicate
   (resolves automatically when follow-up #1 lands).

## Open issues to be aware of (in DB)

Run `psql -d psypi -c "SELECT id, title, status, severity FROM issues WHERE status='open' ORDER BY created_at DESC LIMIT 10;"` for the live list.

## How to resume

```bash
cd /Users/jk/gits/hub/tools_ai/psypi
# 1. Confirm branch + see what shipped
git log --oneline develop..HEAD   # should show 6 commits
# 2. Verify A's soul is reordered
psql -d psypi -c "SELECT id_prefix, position('## Conversational Frame' in content) AS cf_pos, position('## Communication' in content) AS comm_pos FROM agent_souls WHERE is_active=true;"
# Expect: cf_pos (3492) > comm_pos (3141) — Conversational Frame comes after Communication
# 3. Verify job counts match the snapshot in AGENTS.md
psql -d psypi -c "SELECT s.id_prefix, COUNT(*) FROM agent_jobs j JOIN agent_souls s ON j.soul_id = s.id WHERE j.is_active = true AND s.is_active = true GROUP BY s.id_prefix ORDER BY s.id_prefix;"
# Expect: A=24, S=20
# 4. Run tests
gleam test   # should be 98 passed
```

**Read order for the next session:**
1. **First:** "Key insight" (Conversational Frame) — the 锵锵三人行
   analogy is the most important thing to internalize before touching
   A's code
2. **Then:** "Key insight #2" (append-only) — the new design
   direction; the next session is a *discussion* session, not an
   implementation session
3. **Then:** AGENTS.md (the canonical project guide)
4. **Then:** `docs/A-BOT-POST-FIX-FINDINGS-2026-06-02.md` (the 4 open
   post-fix behaviors, especially Finding 1 about de-dup)
5. **Then:** Run the 4 verification queries above
6. **Then:** Open the append-only discussion with the user. Present
   Options A / B / C from the "Key insight #2" section. Let the user
   pick. **Do not start implementation before the user has chosen.**

## Lessons from this session

1. **File-driven soul edits are reliable**: Edit a temp file, embed
   via dollar-quoted SQL, sync to seed files. Each step is verifiable.
2. **Always cross-check 3 storage locations**: DB, `seed.gleam`,
   `008_agent_soul.sql`. They MUST stay byte-identical for fresh installs.
3. **Idempotent migrations > smart migrations**: Use `WHERE NOT EXISTS`
   or `WHERE id = ...` guards so re-runs are safe.
4. **Snapshot tables in docs are documentation, not source of truth**:
   Mark them as "snapshot" and provide the live psql query. Update them
   on every job change, not just on schema changes.
5. **A single tool call (sql/grep/Read) beats a long debate**: When
   the user asks "is the table up to date", query the DB and diff.
6. **The schema was right; the usage was wrong.** When something feels
   broken about a DB design, first audit *how* the table is used
   (UPDATE vs INSERT pattern) before changing the schema. `inter_reviews`
   is the model; `agent_souls` and `agent_jobs` should learn from it.
7. **The user's late-session corrections are higher-signal than
   mid-session work.** The append-only insight at the end of the
   session changes the design direction. If a future session finds
   the user's "just wrap it up" tone at the end of THIS session, it
   should treat that as a flag that the next session must slow down
   and discuss, not race to implement.

## Meta — how this session was conducted

This session covered a lot of ground: a real reordering of the soul,
a fresh principle documented in issue 045, a doc sync, a handover
doc, and a key design insight at the end. The user explicitly
**pushed back twice** on the agent's framing:

- First, the agent proposed a DB trigger for history preservation.
  The user said: that's not the problem; the problem is using UPDATE
  when you should be INSERTing. **Append-only is the answer; the
  trigger is a workaround.**
- Second, the user said: stop trying to complete things in the
  current session; just write a good handover. The next session
  is the place for the append-only discussion.

The right behavior in the next session is: **ask the user to pick
between Option A / B / C on the append-only decision, and let them
choose before any work begins.** Do not assume Option C (meeting) is
the answer just because the agent recommends it.
