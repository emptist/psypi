# PsyPI Architecture — Identity and Coordination

## Core Principle

**ID is everything. Everything is ID.**

The ID encodes:
- Role (A/S) — from `ctx.isIdle()`
- Model — from `ctx.model.id`
- Source — from `ctx.model.provider`
- Thinking level — from `ctx.model.thinkingLevel`
- Project — from `ctx.cwd`

## Identity: Pure Function

`semantic_id(ctx)` is a **pure function**:
- Same `IdentityContext` → same ID, always
- No side effects, no DB access, no hidden state

## A/S Dual Workflow

Two agentbots share one Pi extension:
- **A (Autonomic)**: Wakes when S is idle. Reads SOUL + jobs from DB, composes system prompt, calls LLM via `call_monitor`, sends polite reminders to S via `sendMessage()`
- **S (Somatic)**: The main coding agent. Reads SOUL from DB via `before_agent_start` hook. Receives A's messages as natural language.

### Communication: The LLM is the Protocol

A communicates with S via `sendMessage()`. S is an LLM — it reads and understands natural language. No database intermediary needed.

**Anti-pattern to avoid**: Building database-mediated communication pipelines (like the removed `system_directives` table). See README.md "Lesson: The system_directives Anti-Pattern".

## System Prompt Composition

Both A and S read their identity from the `agent_souls` table (joined by `id_prefix`):

- **A**: `hook_on_agent_end` → `a_db_reader` reads soul + jobs → `a_prompt_builder` composes prompt → `call_monitor` calls LLM
- **S**: `hook_on_before_agent_start` → `s_db_reader` reads soul → returns as system prompt override

System prompt is bounded by context window. `system_prompt_types.gleam` provides `PromptComposition` with priority-based budget management.

## File Structure

```
src/
  agent_identity.gleam          -- semantic_id computation + DB soul reader
  agent_identity_types.gleam    -- IdentityContext, AgentIdentity, IdentityError
  hook_on_agent_end.gleam       -- A-S coordination: debounce + call_monitor
  hook_on_before_agent_start.gleam -- S system prompt from DB
  hook_on_agent_start.gleam     -- S session start event
  hook_on_tool_call.gleam       -- tool call event
  hook_on_tool_result.gleam     -- tool result event
  a_db_reader.gleam             -- A's DB reads: soul, jobs, project state (id_prefix='A')
  a_prompt_builder.gleam        -- A's system/user prompt composition
  a_context_utils.gleam         -- Context window parsing, time utilities
  s_db_reader.gleam             -- S's DB reads: soul (id_prefix='S')
  pi_tool_call.gleam            -- PiToolCall, PiEventHook, PiCommandReg types + generators
  extension_generator.gleam     -- Generates extension.js from Gleam typed values
  pi_extension_ffi.mjs          -- FFI: call_monitor, sendMessage, notify, renderers
  system_prompt_types.gleam     -- PromptComposition with context window budget
```

## Typed Pipeline: Gleam → JS

The architecture ensures AIs write Gleam, not JS:

1. Domain modules define typed values: `PiToolCall`, `PiEventHook`, `PiCommandReg`
2. Generator functions (`to_js_text()`, `event_hook_to_js()`, `command_to_js()`) convert these to JS text
3. `extension_generator` collects and composes them into `extension.js`
4. FFI functions (`pi_extension_ffi.mjs`) handle runtime JS that can't be generated

No raw JS strings in Gleam files. No `PiRawHook` or `PiRawCommand` escape hatches.
