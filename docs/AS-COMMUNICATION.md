# A-S Communication System

## Core Principle

**The LLM is the protocol.** When two LLMs need to coordinate, use natural language messages.

For the full A/S dialogue model (alternating current, quality guardian role, dialogue protocol), see **README.md → "The A/S Dialogue Model"**.

A communicates with S via `sendMessage()`. S is an LLM — it reads and understands natural language directly. No database intermediary needed.

## The ID Encodes Identity

```
A-tools_ai-openrouter-owl-alpha-high
│        │         │         │     │
│        │         │         │     └─ thinking level (optional)
│        │         │         └─ model (from ctx.model.id)
│        │         └─ source/provider (from ctx.model.provider)
│        └─ project (from ctx.cwd)
└─ role: A=Autonomic, S=Somatic
```

`semantic_id(ctx)` is a pure function: same `IdentityContext` → same ID, always.

## How A-S Exchange Happens

### S-agentbot side (normal operation)
1. User sends prompt
2. `before_agent_start` fires → S reads SOUL from `agent_souls` WHERE `id_prefix='S'`
3. S processes prompt, calls tools, etc.
4. `agent_end` fires → S is done

### A-agentbot side (agent_end coordination)
1. `agent_end` fires → S finished
2. Wait for debounce period (configurable via `psypi_config` table)
3. Check `ctx.isIdle()` → is S still idle?
4. If NO → S got new work, skip
5. If YES → A reads SOUL + jobs from DB via `a_db_reader` (id_prefix='A')
6. A composes system prompt via `a_prompt_builder`
7. A calls LLM via `call_monitor`
8. A sends message to S via `sendMessage()`

### The Exchange
- A sends: `pi.sendMessage({ customType: 'autonomic-wakeup', content: msg })`
- S receives: the message appears in session as natural language
- S decides: what to do next based on its own SOUL and judgment

**No explicit handshake. No shared state. Just the message.**

## ctx.isIdle() — The Gate

`ctx.isIdle()` is the ONLY check needed:
- `true` → S is idle → A can speak
- `false` → S is busy → A stays silent

## Debounce

After `agent_end` fires, S might immediately get a new prompt. The debounce prevents A from interrupting.

- Default: 5 minutes (300000ms) from `psypi_config` table
- Fallback: 15 minutes (900000ms) if DB read fails

## Key Design Decisions

### Why sendMessage() instead of database-mediated directives?

The removed `system_directives` anti-pattern tried to use a database table + Pi tools + hook injection for A→S communication. This was over-engineered: S is an LLM that understands natural language. A just needs to talk to S. See README.md "Lesson: The system_directives Anti-Pattern".

### Why typed pipeline instead of raw JS strings?

The old architecture had hardcoded JS strings in Gleam files. The typed pipeline (`PiToolCall`, `PiEventHook`, `PiCommandReg`) ensures AIs write Gleam, not JS. Generator functions convert typed values to JS text through structured pattern matching.

### Why pass A-agentbot ID to call_monitor?

The LLM needs to know who it is. The ID tells the LLM: "You are A-tools_ai-openrouter-owl-alpha" — the Autonomic Agentbot. The LLM can then compose a contextually appropriate message.

## File Structure

```
src/
  agent_identity.gleam          -- semantic_id computation + DB soul reader
  agent_identity_types.gleam    -- IdentityContext, AgentIdentity, IdentityError
  hook_on_agent_end.gleam       -- A-S coordination: debounce + call_monitor
  hook_on_before_agent_start.gleam -- S system prompt from DB
  a_db_reader.gleam             -- A's DB reads: soul, jobs, project state (id_prefix='A')
  a_prompt_builder.gleam        -- A's system/user prompt composition
  a_context_utils.gleam         -- Context window parsing, time utilities
  s_db_reader.gleam             -- S's DB reads: soul (id_prefix='S')
  pi_tool_call.gleam            -- PiToolCall, PiEventHook, PiCommandReg types + generators
  extension_generator.gleam     -- Generates extension.js from Gleam typed values
  pi_extension_ffi.mjs          -- FFI: call_monitor, sendMessage, notify, renderers
  system_prompt_types.gleam     -- PromptComposition with context window budget
```
