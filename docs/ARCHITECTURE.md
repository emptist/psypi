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
  agents.gleam                  -- psypi-agents tool
  areflect.gleam                -- psypi-areflect: extract markers from text
  broadcast.gleam               -- psypi-broadcast-send/list
  code_version.gleam            -- psypi-doc-save/list
  command_listen.gleam          -- autonomic-listen command
  command_reload.gleam          -- autonomic-reload command
  db.gleam                      -- PostgreSQL connection pool (node_pg FFI)
  event_hooks.gleam             -- Hook trigger recording
  extension_generator.gleam     -- Generates extension.js from Gleam typed values
  file_utils.gleam              -- File read/write helpers
  hook_on_agent_end.gleam       -- A-S coordination: debounce + idle_since gating + call_monitor
  hook_on_agent_start.gleam     -- S session start event
  hook_on_before_agent_start.gleam -- S system prompt from DB
  hook_on_tool_call.gleam       -- tool call event
  hook_on_tool_result.gleam     -- tool result event
  inter_review.gleam            -- Inter-review meeting creation
  issue_db.gleam                -- Issue DB operations
  issue_tools.gleam             -- psypi-issue-* tools
  issue_types.gleam             -- Issue type definitions
  learning.gleam                -- psypi-learn-save
  main.gleam                    -- Entry point
  meeting.gleam                 -- psypi-meeting-* tools
  memory.gleam                  -- psypi-memory-search
  monitor.gleam                 -- Model recording
  monitor_ai.gleam              -- psypi-autonomic-* tools
  pi_extension.gleam            -- FFI imports: notify, ctx_*, now_ms, get/set_config
  pi_extension_ffi.mjs          -- FFI: call_monitor, sendMessage, notify, now_ms, get/set_config
  pi_tool_call.gleam            -- PiToolCall, PiEventHook, PiCommandReg types + JS generators
  psypi_config.gleam            -- psypi_config table reads/writes
  s_db_reader.gleam             -- S's DB reads: soul (id_prefix='S')
  seed.gleam                    -- DB seed data
  simple_migrate.gleam          -- Migration runner
  skill.gleam                   -- psypi-skill-* tools
  stats.gleam                   -- psypi-stats-show
  system_prompt_types.gleam     -- PromptComposition with context window budget
  task.gleam                    -- psypi-task-add/list/complete
  tool_commit.gleam             -- psypi-commit tool
  tool_consult.gleam            -- psypi-consult-autonomic tool
  a_context_utils.gleam         -- Context window parsing, time utilities
  a_db_reader.gleam             -- A's DB reads: soul, jobs, project state (id_prefix='A')
  a_orchestrator.gleam          -- A's workflow: fully_functional gate + full workflow
  a_prompt_builder.gleam        -- A's system/user prompt composition + inter-review detection
```

## Typed Pipeline: Gleam → JS

The architecture ensures AIs write Gleam, not JS:

1. Domain modules define typed values: `PiToolCall`, `PiEventHook`, `PiCommandReg`
2. Generator functions (`to_js_text()`, `event_hook_to_js()`, `command_to_js()`) convert these to JS text
3. `extension_generator` collects and composes them into `extension.js`
4. FFI functions (`pi_extension_ffi.mjs`) handle runtime JS that can't be generated

No raw JS strings in Gleam files. No `PiRawHook` or `PiRawCommand` escape hatches.
