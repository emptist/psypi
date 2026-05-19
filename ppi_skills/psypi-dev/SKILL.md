---
name: psypi-dev
description: psypi development knowledge — architecture, system prompt pipeline, A-S dual workflow, SOUL mechanism, and codebase conventions
---

# psypi Development Knowledge

## Core Principle: Everything Is System Prompt

All mechanisms in psypi serve one purpose: **composing the system prompt that the AI sees**.

- SOUL = content injected into system prompt
- Skills = content injected via `<available_skills>` in system prompt
- Directives = content injected into system prompt
- `pi_send_message` = content injected as user message

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
- A's SOUL comes from `souls` table → passed as `call_monitor` systemPrompt
- A autonomously composes messages for S based on events and context
- A uses tools: `psypi-direct-agentbot`, `pi_send_message`

### S-agentbot (Somatic)
- Prompt-driven task executor
- Runs through Pi agent loop
- S gets system prompt through Pi standard mechanisms
- S's SOUL + directives should be injected through these standard Pi interfaces

## SOUL Mechanism

SOUL lives in PostgreSQL `souls` table:
- `agent_id` (e.g., `A-psypi-psypi`, `S-psypi-psypi-unknown`)
- `name` (Autonomic, Somatic)
- `content` (full identity definition — role, behavior, responsibilities, self-evolution, boundaries)
- `traits` (JSON: focus, speed, quality, autonomy)

SOUL is NOT a special Pi mechanism. Pi has no concept of SOUL. SOUL is psypi's invention — content from the database that gets composed into system prompt.

### How SOUL enters system prompt
- **A**: `call_monitor(ctx, userPrompt, soulContent)` — hook code reads SOUL from DB, passes as systemPrompt
- **S**: Pi standard injection (before_agent_start, resources_discover, etc.) — reads SOUL from DB

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

**Current broken pipeline**: Data exists in DB (`souls`, `system_directives`) but never gets read into system prompt. The write end works (A writes directives), the read end is broken (nothing reads directives into S's system prompt).

## Key Files

| File | Purpose |
|---|---|
| `src/hook_on_agent_end.gleam` | A-S coordination: reads SOUL from DB, composes system prompt with budget, calls call_monitor for A to autonomously decide |
| `src/directive.gleam` | Directive CRUD + SOUL prefix (write end works) |
| `src/pi_extension_ffi.mjs` | FFI: call_monitor, pi_send_message, notify_info |
| `src/extension_generator.gleam` | Generates extension.js from Gleam modules |
| `src/ppi_gen.gleam` | Generates bin/ppi.mjs entry point |
| `src/agent_identity_types.gleam` | IdentityContext, AgentIdentity types |
| `src/agent_identity.gleam` | Identity computation (pure function) |
| `src/system_prompt_types.gleam` | System prompt types with context window budget |
| `docs/MONITOR-BRIEF.md` | A-agentbot's operating manual (content now in DB SOUL too) |

## Context Window Constraint

System prompt is bounded by context window. Every component (SOUL, directives, skills, context files) consumes tokens.

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
- Priority order: Critical (SOUL) > High (directives) > Medium (skills) > Low (context files)
- Token estimation: `string.length(text) / 4 + 1`

### Token estimation
Rough rule: 1 token ≈ 4 characters for English, ≈ 2 characters for Chinese.
Gleam types should include `estimated_tokens: Int` field for each component.

## Critical Rules

1. **Never invent custom injection mechanisms** — use Pi standard interfaces only
2. **Never hardcode SKIP/STANDBY logic** — A decides autonomously based on SOUL
3. **Database is the bridge** — A writes, S reads, via standard Pi interfaces
4. **Hooks are THIN** — just record events and trigger coordination, no blocking logic
5. **Intelligence is in the LLM** — not in JavaScript regex or hardcoded prompts
6. **`before_agent_start` is for S only** — A does not run through Pi agent loop
7. **`call_monitor` is for A** — A's system prompt comes via this function's systemPrompt parameter

## Pi Source Code Reference

Pi source code is at: `../refers/pi/`
- `packages/agent/src/harness/skills.ts` — Skill loading from filesystem
- `packages/agent/src/harness/system-prompt.ts` — `formatSkillsForSystemPrompt()`
- `packages/coding-agent/src/core/system-prompt.ts` — `buildSystemPrompt()`
- `packages/coding-agent/src/core/resource-loader.ts` — Resource loading pipeline
- `packages/coding-agent/src/core/extensions/types.ts` — All event types and interfaces
- `packages/coding-agent/src/core/extensions/runner.ts` — Extension runner (emitBeforeAgentStart, emitResourcesDiscover)
