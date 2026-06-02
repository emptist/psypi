---
name: psypi-dev
description: psypi development knowledge — architecture, system prompt pipeline, A-S dual workflow, SOUL mechanism, and codebase conventions
---

# psypi Development Knowledge

## Core Principle: Everything Is System Prompt

All mechanisms in psypi serve one purpose: **composing the system prompt that the AI sees**.

- SOUL = content injected into system prompt
- Skills = content injected via `<available_skills>` in system prompt
- `pi_send_message` = content injected as user message (A→S communication)

The system prompt is the only interface to the AI. All roads lead to system prompt.

## A-S Dual Workflow

psypi is **one AI operating in two modes** (alternating current):

| Agentbot | Identity | Trigger | How it gets SOUL |
|---|---|---|---|
| **A (Autonomic)** | `A-psypi-psypi` | Events/hooks | `call_monitor(systemPrompt)` — SOUL from DB |
| **S (Somatic)** | `S-psypi-psypi-<session>` | User input / `pi_send_message` | Pi standard injection — SOUL from DB |

They **never run at the same time**. Each one's output becomes the other's input.

### A-agentbot (Autonomic)
- Event-driven, will become fully capable like S
- Runs via `call_monitor()` which takes `systemPrompt` parameter
- A does NOT run through Pi agent loop — `before_agent_start` does NOT apply to A
- A's SOUL comes from `agent_souls` table (id_prefix='A') → passed as `call_monitor` systemPrompt
- A's jobs come from `agent_jobs` table joined via `agent_souls.id_prefix='A'`
- A autonomously composes polite reminders for S based on events and context
- A communicates with S via `sendMessage()` — NOT via database directives

> The "polite reminders" and the inter-review output are A's *turns to speak* in the PDCA conversation, not formal review documents. The `inter_reviews` table is a chat log. See [Conversational Frame](../../docs/DESIGN-A-BOT-NO-TOOLS-2026-06-02.md#conversational-frame-added-2026-06-02-after-user-feedback) for the framing.

### S-agentbot (Somatic)
- Prompt-driven task executor
- Runs through Pi agent loop
- S gets system prompt through `before_agent_start` hook → reads SOUL from `agent_souls WHERE id_prefix='S'`
- S reads A's messages directly — S is an LLM, it understands natural language

## SOUL Mechanism

SOUL lives in PostgreSQL `agent_souls` table:
- `id_prefix` (e.g., `'A'`, `'S'`) — the key field for joining with other tables
- `name` (Autonomic, Somatic)
- `content` (full identity definition — role, behavior, responsibilities, self-evolution, boundaries)
- `role`, `domain`, `responsibility` — structured fields also available

SOUL is NOT a special Pi mechanism. Pi has no concept of SOUL. SOUL is psypi's invention — content from the database that gets composed into system prompt.

### How SOUL enters system prompt
- **A**: `call_monitor(ctx, userPrompt, soulContent)` — `hook_on_agent_end` reads SOUL + jobs from DB via `a_db_reader`, composes system prompt via `a_prompt_builder`, passes as systemPrompt
- **S**: `before_agent_start` hook reads SOUL from DB via `s_db_reader.read_s_soul_from_db()` → returns as system prompt override

## System Prompt Injection Methods (Pi Standard)

| Method | Mechanism | When |
|---|---|---|
| `customPrompt` | Replace entire system prompt | Init |
| `appendSystemPrompt` | Append to system prompt | Init |
| `contextFiles` | `# Project Context` section | Init |
| `skills` | `<available_skills>` section | Init, AI reads on demand |
| `before_agent_start` → `systemPrompt` | Replace current system prompt | Every agent loop start |
| `before_agent_start` → `message` | Inject message | Every agent loop start |
| `resources_discover` → `skillPaths` | Add skill directories dynamically | Session start/reload |
| `.pi/SYSTEM.md` | Replace system prompt | File exists |
| `.pi/APPEND_SYSTEM.md` | Append system prompt | File exists |

**Do not confuse injection method with injection node.**
- Method = read SOUL from DB → compose into system prompt text
- Node = when/where to inject (timing)
- The method is essential. The node is just timing.

## Database-First Design

psypi uses database-first design so it can work across projects without filesystem dependency.

**Pipeline**: DB read → compose system prompt text → inject via Pi standard interface

**Fixed pipeline**: Both A and S now read their SOUL from `agent_souls` table via `id_prefix`. A reads its jobs from `agent_jobs` joined by `id_prefix='A'`. S reads its soul via `id_prefix='S'`. No `system_directives` needed — A→S communication uses `sendMessage()`.

## Lesson: The `system_directives` Anti-Pattern

A previous AI built an entire pipeline for A→S communication that was completely unnecessary: `system_directives` table, `psypi-direct-agentbot` tool, `psypi-clear-directives` tool, `directive.gleam` module, and `before_agent_start` directive-reading logic. None of it was needed — S is an LLM that understands `sendMessage()`. The write end worked (A could insert rows), but the read end was never connected. The hook just returned a hardcoded string.

**Why it happened:** Confusing "system prompt injection" (a Pi SDK mechanism) with "communication" (a natural language act). A doesn't need to modify S's system prompt — A just needs to talk to S.

**Correct pattern:** A→S communication = `sendMessage()`. Both bots read their own soul/jobs from DB via `id_prefix` for their identity, not for inter-agent communication. **The LLM is the protocol.**

## Key Files

| File | Purpose |
|---|---|
| `src/hook_on_agent_end.gleam` | A-S coordination: reads SOUL + jobs from DB, composes system prompt with budget, calls call_monitor for A to autonomously decide |
| `src/hook_on_before_agent_start.gleam` | S's system prompt: reads SOUL from DB via s_db_reader |
| `src/a_db_reader.gleam` | A's DB reads: soul, jobs, project state (all joined by id_prefix='A') |
| `src/s_db_reader.gleam` | S's DB reads: soul, jobs (all joined by id_prefix='S') |
| `src/a_prompt_builder.gleam` | A's system/user prompt composition with polite reminder style |
| `src/a_context_utils.gleam` | Context window parsing utilities |
| `src/pi_extension_ffi.mjs` | FFI: call_monitor, pi_send_message, notify_info |
| `src/extension_generator.gleam` | Generates extension.js from Gleam modules |
| `src/agent_identity.gleam` | Identity computation (pure function) |
| `src/system_prompt_types.gleam` | System prompt types with context window budget |

## Context Window Constraint

System prompt is bounded by context window. Every component (SOUL, jobs, skills, context files) consumes tokens.

### Pi's ContextUsage interface
```typescript
interface ContextUsage {
  tokens: number | null;       // current tokens used
  contextWindow: number;       // total window size
  percent: number | null;      // usage percentage
}
```
Access: `ctx.getContextUsage()` → `ctx_get_context_usage_json(ctx)` in Gleam FFI.

### Design principle
System prompt types MUST carry token budget awareness:
- `PromptComponent` — kind (Soul/Directive/Skill/ContextFile/Custom), priority, content, estimated_tokens
- `ContextBudget` — total_tokens, used_tokens
- `PromptComposition` — list of components + budget
- `compose_within_budget()` — sorts by priority, keeps components until budget exhausted
- Priority order: Critical (SOUL) > High (jobs) > Medium (skills) > Low (context files)
- Token estimation: `string.length(text) / 4 + 1`

### Token estimation
Rough rule: 1 token ≈ 4 characters for English, ≈ 2 characters for Chinese.
Gleam types should include `estimated_tokens: Int` field for each component.

## Critical Rules

1. **Never invent custom injection mechanisms** — use Pi standard interfaces only
2. **Never hardcode SKIP/STANDBY logic** — A decides autonomously based on SOUL
3. **A→S communication = `sendMessage()`** — S is an LLM, it reads natural language. No database intermediary needed.
4. **Hooks are THIN** — just record events and trigger coordination, no blocking logic
5. **Intelligence is in the LLM** — not in JavaScript regex or hardcoded prompts
6. **`before_agent_start` is for S only** — reads S's SOUL from DB via `id_prefix='S'`
7. **`call_monitor` is for A** — A's system prompt comes via this function's systemPrompt parameter
8. **Tables joined by `id_prefix`** — `agent_souls`, `agent_jobs` use `id_prefix` ('A' or 'S') as the key, not agent_id or other fields

## Pi Source Code Reference

Pi source code is at: `../refers/pi/`
- `packages/agent/src/harness/skills.ts` — Skill loading from filesystem
- `packages/agent/src/harness/system-prompt.ts` — `formatSkillsForSystemPrompt()`
- `packages/coding-agent/src/core/system-prompt.ts` — `buildSystemPrompt()`
- `packages/coding-agent/src/core/resource-loader.ts` — Resource loading pipeline
- `packages/coding-agent/src/core/extensions/types.ts` — All event types and interfaces
- `packages/coding-agent/src/core/extensions/runner.ts` — Extension runner (emitBeforeAgentStart, emitResourcesDiscover)
