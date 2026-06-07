# Current State — 2026-06-06

## What Works
- ✅ 44 Pi tools registered and functional
- ✅ 7 event hooks (including debounced agent_end)
- ✅ 2 commands (autonomic-listen, autonomic-reload)
- ✅ 2 message renderers (autonomic-wakeup, autonomic-error)
- ✅ A/S dual-agent model with debounce timer
- ✅ Build and regeneration — `gleam build` + `gleam test` (109 tests)
- ✅ ppi.mjs runs Pi with generated extension.js
- ✅ ppitest.mjs for testing outside Pi runtime

## FnArgument Migration — COMPLETED (2026-06-06)

Replaced all hand-written JS strings in tool/hook/command definitions with structured Gleam types.

### New Types
- **ParamSrc** — describes WHERE to get a value (ParamField, OptionalParamField, IntParamField, EventField, EventJsonField, EventFilePath, CtxField, ArgsField)
- **FnArgument** — describes WHAT to pass (FromParam(ParamSrc), Ctx, Pi, StringConst, IntConst, NullConst)
- **HookGuard** — describes WHEN a hook executes (CtxFieldExists, EventFieldExists, NoGuard)

### Deleted (old types/functions)
- `FnArg` type (JsLiteral, FromParamLegacy variants)
- `JsLiteral` — arbitrary JS expression strings
- `FromParam(String)` — arbitrary JS access expressions
- `CustomJs(String)` in ResultFormat — arbitrary JS result expressions
- `custom_js()` function
- `lit()`, `from_param()`, `new_arg()` bridge functions

### Files Modified
- `pi_tool_call.gleam` — core types and JS generation
- `extension_generator.gleam` — registries using new constructors
- `task.gleam`, `skill.gleam`, `memory.gleam`, `learning.gleam`
- `areflect.gleam`, `broadcast.gleam`, `meeting.gleam`
- `monitor_ai.gleam`, `agent_identity.gleam`
- `system_review_tools.gleam`, `issue_tools.gleam`, `code_version.gleam`
- `test/pi_tool_call_test.gleam`

### Key Design Decisions
- `??` (nullish coalescing) replaces `||` (logical OR) — correct for empty string defaults
- `parseInt()` wraps integer params — Pi passes all params as strings
- Optional chaining `params?.name` for optional params
- `ctx` passed directly (not destructured object) — Gleam code accesses ctx via FFI
- Double quotes for StringConst — consistent JS style
- Tool errors use `ctx_notify` (toast for humans) + return value (for S-bot) — both channels needed
- Hook errors use `pi.sendMessage` (persistent, no return value alternative)

### Generator Integrity
- **Zero hand-written JS strings** in the entire generator pipeline
- All JS is mechanically generated from structured Gleam types
- `generate()` output verified identical before/after migration
- No `CustomJs` escape hatch exists — impossible to inject arbitrary JS

## Architecture
- **Generator**: Gleam types → JS text → extension.js (via `generate()` in ppi.mjs)
- **A-bot**: event-driven, reads hooks, writes DB/messages
- **S-bot**: prompt-driven, reads system prompt, produces events
- **Alternating current**: each one's output = other's input
- **Debounce timer**: A-bot only fires after S-bot idle for continuous debounce period

## Build & Deploy
```bash
gleam clean && gleam build
gleam test  # 109 tests
./bin/ppi.mjs  # generates extension.js and starts Pi
```

## Open Issues
- `monitor_ai.gleam:92` — TODO: housekeeping (archive old versions, clean stale config)
