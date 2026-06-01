# A-bot Context Problems — Investigation Report

## Date
2026-06-01

## Source
Conversation dump saved by user in `src/A-bot-thinking.md` (not a project document — a raw A-bot conversation captured for analysis).

## Problem 1: A-bot hallucinates sqlite3

### Evidence

From the conversation dump (lines 79-84):

```
Now let me check the DB schema before writing — I need to get the column names right to avoid the hallucination issue.
<longcat_tool_call>run_terminal
<longcat_arg_key>command</longcat_arg_key>
<longcat_arg_value>cd /Users/jk/gits/hub/tools_ai/psypi && sqlite3 psypi.db ".schema inter_reviews"</longcat_arg_value>
</longcat_tool_call>
<longcat_tool_call>run_terminal
<longcat_arg_key>command</longcat_arg_key>
<longcat_arg_value>cd /Users/jk/gits/hub/tools_ai/psypi && sqlite3 psypi.db ".schema review_findings"</longcat_arg_value>
</longcat_tool_call>
```

A-bot tried to use `sqlite3 psypi.db` to check the schema. This is wrong on multiple levels:
1. **psypi uses PostgreSQL**, not SQLite
2. **The database name is `psypi`**, not `psypi.db`
3. **The correct command is** `psql -d psypi -c "\d inter_reviews"`
4. **A-bot shouldn't need to run terminal commands at all** — it has Pi tools for DB access

### Root Cause

The sqlite3 hallucination comes from **two sources**:

#### Source 1: DESIGN-PROJECT-ID-AS-URL.md line 42

```markdown
3. **SQLite column changes** from `uuid` to `text` — stores the URL string or path string
```

This design doc incorrectly mentions "SQLite" when it should say "PostgreSQL". A-bot reads this doc (or a previous session summarized it), and the word "SQLite" gets embedded in its context.

#### Source 2: awesome-gleam.md references

The skill file `ppi_skills/gleam-language/references/awesome-gleam.md` lists multiple SQLite libraries:
- `cake` — SQL query builder for PostgreSQL, SQLite, MariaDB, MySQL
- `migrant` — Database migrations for SQLite in Gleam
- `sqlight` — Use SQLite from Gleam!

These are in A-bot's skill context. The LLM sees "SQLite" in the Gleam ecosystem references and associates it with database access.

#### Source 3: No explicit "we use PostgreSQL" in A's prompt

A-bot's system prompt (composed by `a_prompt_builder.gleam`) contains:
- Soul content (behavioral rules)
- Jobs list
- Project state (tasks, issues)
- Recent commits
- Recent conversation

It does NOT contain:
- What database psypi uses
- How to access the database
- What tools to use for DB queries
- The DB schema

### Fix

1. **Fix DESIGN-PROJECT-ID-AS-URL.md** — change "SQLite column changes" to "PostgreSQL column changes"
2. **Add DB access rules to A's soul** — "psypi uses PostgreSQL. Access it via `psql -d psypi` or Pi tools. Never use sqlite3."
3. **Add DB schema summary to A's prompt** — table names, column names, types (addresses issue `5e0e4283`)

## Problem 2: A-bot tries to run terminal commands

### Evidence

The conversation dump shows A-bot generating `<longcat_tool_call>run_terminal` XML blocks. This is A-bot hallucinating that it has terminal access — it doesn't. A-bot runs inside the Pi extension's `agent_end` hook, which only has access to:
- `ctx` (Pi context object)
- `pi` (Pi API object)
- `call_monitor()` (LLM call)
- `pi_send_message()` (message sending)
- `ctx_notify()` (UI notifications)
- Pi tools registered in the extension

A-bot does NOT have:
- Terminal/shell access
- File system access (except via `read_file_sync` FFI)
- Direct database access (except via Pi tools like `psypi-issues`, `psypi-tasks`)

### Root Cause

A-bot's LLM response is free-form text. The LLM doesn't know it's running inside a constrained hook — it thinks it's a full agent with terminal access. The system prompt doesn't explicitly say "you cannot run terminal commands."

### Fix

Add to A's soul: "You run inside the agent_end hook. You have NO terminal access. You can only: call_monitor(), pi_send_message(), ctx_notify(), and use registered Pi tools. Never generate terminal commands."

## Problem 3: A-bot's first thought wakes S-bot

### Evidence

From the conversation dump, A-bot's analysis starts with:

```
[A-agentbot] Sending wake-up message...
[A-agentbot] [A-agentbot]
I need to perform my Check duties. Let me start by reading the soul/jobs from the DB...
```

Then A-bot proceeds to do a full analysis, but the FIRST `pi_send_message` call (with `triggerTurn: true` in the documented design) would have woken S immediately, before A finished thinking.

### Root Cause

The current code flow in `hook_on_agent_end.gleam`:
1. A calls `call_monitor()` → LLM returns full analysis text
2. A sends the ENTIRE analysis as one `pi_send_message` call

The problem: `call_monitor()` returns the LLM's complete response. But the LLM might produce a "thinking out loud" response that includes partial analysis, self-corrections, and dead ends. Sending all of this as a wake-up message is noisy and confusing for S.

### The Deeper Issue

A-bot's `call_monitor()` call uses a free-form system prompt. The LLM responds with whatever it wants — sometimes a structured review, sometimes a stream of consciousness. There's no structured output format.

Compare with the Pi SDK's `plan-mode` example, which uses `triggerTurn: true` ONLY after the user explicitly chooses "Execute the plan" — a clear, intentional action. A-bot has no such gate.

### Fix (see ADR-pi-send-message-abuse.md)

The inter-review gate: A must write a structured inter-review to the database BEFORE sending `triggerTurn: true`. This ensures:
1. A's output is structured (not stream of consciousness)
2. A has proof of work before waking S
3. S has a concrete review to respond to

## Problem 4: A-bot's analysis is shallow and confused

### Evidence

From the conversation dump, A-bot's analysis includes:

```
Wait — I see the issue. Reviewing the conversation: S's last action was calling psypi-my-id, which is S's own tool. This suggests S responded to an A message.
...
Actually — I'm entering my Check cycle NOW.
```

A-bot is confused about its own state. It doesn't know:
- Whether it's in Waiting or Working mode
- What S did in the previous session
- Whether its own previous cycle produced results
- What the inter_reviews table contains

### Root Cause

A-bot's context is limited to:
1. Soul content (behavioral rules) — static
2. Jobs list — static
3. Project state (10 tasks, 10 issues) — just titles and IDs
4. Recent commits — git log output
5. Recent conversation entries — last 4000 chars of S's conversation

Missing from A's context:
- A's OWN previous reviews (inter_reviews table)
- A's OWN previous session output
- Whether A's previous findings were addressed
- The full DB schema (for Check quality)
- What tools A has access to

### Fix

1. Add `a_db_reader.read_last_inter_review()` — A should see its own previous work
2. Add follow-up check to A's jobs: "Did S address your last review?"
3. Include inter_reviews in A's project state summary

## Summary of Documentation Errors Found

| File | Line | Error | Fix |
|------|------|-------|-----|
| DESIGN-PROJECT-ID-AS-URL.md | 42 | "SQLite column changes" | Change to "PostgreSQL column changes" |
| AS-COMMUNICATION.md | 335 | Documents `triggerTurn: true` | Update to reflect inter-review gate |
| AGENTS.md | 335 | Documents `triggerTurn: true` | Update to reflect inter-review gate |
| SYSTEM-PROMPT-INJECTION.md | N/A | Documents `deliverAs: "nextTurn"` | Correct but not used in code |
| README.md | 199 | "Use sqlite3 (PostgreSQL is the database)" | Correct but confusing phrasing |

## Action Items

1. Fix `DESIGN-PROJECT-ID-AS-URL.md` — remove SQLite reference
2. Add DB access rules to A's soul content
3. Add "no terminal access" to A's soul content
4. Implement inter-review gate (see ADR)
5. Add A's previous reviews to A's context
6. Update AS-COMMUNICATION.md and AGENTS.md to match inter-review gate design
