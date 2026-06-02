# Inter-Review Design — PDCA Check Between S Sessions

## Date: 2026-06-01
## Status: Implemented (cleaned up)

> **Note (added 2026-06-02)**: This design doc describes the *mechanics* of inter-review (when, by whom, where it lands). The *framing* of A's output was refined the next day: the inter-review is A's *turn to speak* in the PDCA conversation, not a formal review submission. The `inter_reviews` table is a chat log, not a review form. See [Conversational Frame](./DESIGN-A-BOT-NO-TOOLS-2026-06-02.md#conversational-frame-added-2026-06-02-after-user-feedback) for the refined framing (锵锵三人行 / 圆桌派 analogy) and [`A-CONVERSATIONAL-FRAME-FINDINGS-2026-06-02.md`](./A-CONVERSATIONAL-FRAME-FINDINGS-2026-06-02.md) for the rationale. The mechanics below are unchanged; only the framing of A's output is relaxed.

---

## What Is Inter-Review?

Inter-review is **A-bot's Check in the PDCA cycle**. The "inter-" prefix is literal — it happens **between S-bot sessions**, not gated on commits, not 1:1 with tasks.

```
S plans & does → A checks (inter-review) → S acts → S plans & does → A checks → ...
```

### PDCA Cycle

| Phase | Agent | What |
|-------|-------|------|
| **Plan** | S (or A suggests) | Decide what to do next |
| **Do** | S | Write code, commit, use tools |
| **Check** | A | Inter-review between S sessions |
| **Act** | S | Address A's findings, improve |

---

## Inter-Review vs System-Review

| Aspect | Inter-Review | System-Review |
|--------|-------------|---------------|
| Nature | A's **Check** between S sessions (PDCA) | Comprehensive audit of entire system |
| Scope | What S just produced (code, docs, data, decisions) | Entire codebase + DB schema + docs + config |
| Timing | Between S sessions (every A cycle) | Periodic / on-demand |
| Who | A-bot (autonomous) | S-bot (or external AI invited by user) |
| Inputs | S's recent work | All source files, DB schema, docs, configs |
| Focus | Correctness, behavior, data quality | Architecture, type coverage, tech debt, completeness |
| Output | `inter_reviews` table | `system_reviews` + `review_findings` tables |
| PDCA role | **Check** | S doing a deep self-assessment |
| Analogy | Doctor checking vitals between shifts | Annual full-body scan |

---

## Commit Workflow

`psypi-commit` is simple: it commits immediately with the agent ID appended.

```
S makes changes → S calls psypi-commit("message") → commit lands with [AI:<id>] tag
```

**No review gate. No two-phase flow. No `review_id` parameter.**

After commit, S goes idle → A wakes → A performs inter-review (PDCA Check) → A saves findings to `inter_reviews` table → A sends results to S for the next cycle.

---

## What A Checks

1. **Behavior compliance** — Did S follow PDCA? Plan before Do?
2. **Code quality** — Conventions, type safety, FFI policy, no fake Gleam
3. **Database quality** — Schema, integrity, type coverage, query patterns
4. **Documentation quality** — Skills, ADRs, README, table_documentation
5. **Inter-review** — Review S's code/doc/data/decisions, save to `inter_reviews` table
6. **Follow-up enforcement** — Verify S addressed previous findings

---

## Review → Issue → Task Closed Loop

```
A-bot inter-review (PDCA Check between S sessions)
  → findings saved to inter_reviews table
  → significant findings also become issues
    → issue comments: root cause analysis, solution discussion, action plan
      → if conflicting views: convene a meeting (psypi-meeting-add)
      → when plan is sound: tasks created from the issue
        → task execution (S does the work)
          → next A cycle: inter-review checks S's work + follow-up on prior findings
            → new findings → new issues → new tasks → ...

S-bot system-review (periodic, on-demand)
  → comprehensive audit of entire system
  → findings saved to system_reviews + review_findings tables
  → significant findings become issues → same loop
```

---

## What Inter-Review Is NOT

- **Not a gate on commit** — Commit happens first, review happens after
- **Not 1:1 with commits** — A reviews whatever S produced, not individual commits
- **Not 1:1 with tasks** — No `task_id` binding in the review
- **Not "process monitoring" or "in-process QC"** — Those were old terms that conflated inter-review with continuous monitoring. Inter-review is discrete: A wakes, reviews, files findings, sends to S.
- **Not the same as system-review** — Inter-review is narrow and immediate. System-review is broad and periodic.

---

## Data Flow

```
S-bot works on code
    │
    ▼
S-bot calls psypi-commit("fix: debounce bug")
    │
    ▼
git commit -m "fix: debounce bug [AI:S-psypi-openrouter-owl-alpha]"
    │
    ▼
S-bot becomes idle → debounce timer starts
    │
    ▼
A-bot wakes (debounce elapsed, ctx.isIdle() == true)
    │
    ▼
A-bot loads: soul (agent_souls) + jobs (agent_jobs) + project state
    │
    ▼
A-bot gets recent commits since last_a_session_at (as context)
    │
    ▼
A-bot builds prompt with soul, jobs, state, commits
    │
    ▼
A-bot calls monitor (LLM) — LLM decides what to do based on its jobs
    │
    ▼
A-bot saves inter-review to inter_reviews table (project_url, status='completed',
     summary, overall_score, findings, suggestions, completed_at)
    │
    ▼
A-bot sends LLM's response to S-bot as wake-up message (mentions review_id)
    │
    ▼
A-bot updates last_a_session_at in psypi_config
    │
    ▼
S-bot wakes → reads A's feedback → acts on findings (PDCA Act)
```

---

## Key Files

| File | Role |
|------|------|
| `src/inter_review.gleam` | `save()` — files completed review to `inter_reviews` table |
| `src/a_orchestrator.gleam` | Loads soul+jobs+state+commits, calls LLM, sends result to S |
| `src/a_prompt_builder.gleam` | Builds A's system/user prompt with commit context |
| `src/hook_on_agent_end.gleam` | Debounce logic — only runs A when S is continuously idle |
| `docs/ARCHITECTURE.md` | System architecture overview |
| `AGENTS.md` | Agent quick guide with PDCA cycle |
| `README.md` | Project overview with PDCA comparison table |
| `ppi_skills/psypi-basics/SKILL.md` | Cheat sheet with PDCA cycle |

---

## Cleanup History (2026-06-01)

Removed stale two-phase QC design remnants across all docs and DB:

1. **AGENTS.md** — Removed "Commit Workflow (QC Two-Phase)" section, fixed commit table, fixed A's `id_prefix` description, fixed critical rules (#2), fixed Key Files, fixed debounce description, fixed review loop diagram, fixed FFI count
2. **README.md** — Fixed psypi-commit table entry, replaced inter-review description with PDCA framing, updated comparison table
3. **ppi_skills/psypi-basics/SKILL.md** — Updated commit section with PDCA framing
4. **docs/design_inter_review_commit_separation.md** — Removed fake function names (`create_review_for_commits`, `save_review_result`)
5. **`agent_souls` DB table** — Updated `responsibility` fields, full SOUL `content` for both A and S, job priority 1 description
6. **`src/seed.gleam`** — Updated seed responsibility and activation fields
