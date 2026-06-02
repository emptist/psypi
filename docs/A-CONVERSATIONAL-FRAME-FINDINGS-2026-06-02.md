# A-bot Conversational Frame: Findings and Fix Plan

**Date**: 2026-06-02
**Status**: Plan awaiting execution
**Trigger**: User observation that the A/S interaction is more conversation than process

---

## Finding

The A-bot design (as documented in `DESIGN-A-BOT-NO-TOOLS-2026-06-02.md` and encoded
in A's soul + prompt + docs) framed A's output as a **formal review document**:
"summary, score, findings, suggested next steps". This made A look like a process
artifact generator, not a chat participant.

User's reframing: psypi's A/S loop is structurally a conversation, not a
process pipeline. The PDCA cycle is the *rhythm* of the conversation, not
its substance. A's "inter-review" is just A's *turn* to speak in an ongoing
dialog with S.

The 锵锵三人行 / 圆桌派 analogy:
- A is the **host** (窦文涛): doesn't take a fixed side, asks the awkward question,
  keeps the conversation moving, draws the case out of the guests.
- S is the **work-guest**: brings the substance, does the tool work, answers A's
  questions.
- The optional human is the **second guest**: can intervene, but the show runs
  without them.

A's "no tools" constraint is a runtime fact, not a capability ceiling. A can
ask S anything; S responds; A reads the response next cycle. So A's effective
reach is the union of A's text-LLM and S's entire toolset, routed through
dialogue. A doesn't "hand off" to S — A *uses* S, the way 窦文涛 uses his guests.

## What needs to change

1. **A's soul** — currently says A is a reviewer, a checker, a Check-phase agent.
   Add a "Conversational Frame" section that makes the dialog-first nature
   explicit. No rigid format required; A is free to ask S questions in the same
   message as observations; the inter-review is A's turn to speak.

2. **A's prompt** — currently the user_prompt (in `command_listen.gleam`) tells
   A to "structure the response as a normal inter-review: summary, score,
   findings, suggested next steps." This prescription is the over-formalization
   the user is pushing back against. Remove it. Replace with: "Speak as you
   naturally would. Plain text only — no tool-call XML."

3. **Docs** — `DESIGN-A-BOT-NO-TOOLS-2026-06-02.md` was the design rationale for
   the text-only A. It needs a "Conversational Frame" section explaining that
   the design is *less formal* than the table-of-aspects there suggests. Future
   readers must see the 锵锵三人行 / 圆桌派 analogy before they read the soul,
   or the soul's new section will look like a contradiction.

## What does NOT change

- The `inter_reviews` table schema and `inter_review.save()` flow stay as-is.
  The table is just the chat log; the schema is fine.
- `parse_review_score` stays. Score is now flavor, not the point, but removing
  the parser is bigger surgery than this refactor warrants. The soul can
  de-emphasize the score; the parser remains a useful default.
- The debounce, the activation logic, the trigger paths, the preloaded
  context. All mechanics are unchanged. Only the framing of A's output is
  relaxed.
- The hook's hallucinated-ID strip and the schema-discipline rules in A's
  soul stay. Those are correctness, not format.

## Commit plan

| # | Scope | Files |
|---|---|---|
| 1 | A-soul: add "Conversational Frame" section | new `src/migrations/043_a_soul_conversational_frame.sql` |
| 2 | A-prompt: drop format rigidity in `command_listen.build_user_prompt` | `src/command_listen.gleam` |
| 3 | Docs: add "Conversational Frame" section to design doc | `docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md` |

Each commit is self-contained and can be reverted independently. The soul
migration is idempotent (section-heading guard). The prompt change is a
small string replace. The doc addition is a new section at the end.

## Verification

- `psql -d psypi -t -c "SELECT length(content) FROM agent_souls WHERE id_prefix='A' AND is_active=true;"`
  should increase by ~700 chars after migration 043 runs.
- `gleam build` and `gleam test` should still pass — the prompt builder is
  untouched, the soul change is DB-only, and the test that previously
  failed on the renamed section header is already updated.
- A real session test (the user runs `/autonomic-listen` or waits 3 min for
  the debounce) should show A's response is conversational, not bullet-listy.
