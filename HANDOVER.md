# Handover — 2026-06-06

## FnArgument Migration — COMPLETED

All hand-written JS strings in tool/hook/command definitions replaced with structured Gleam types.

### What Changed
1. **ParamSrc** type — structured parameter sources (ParamField, OptionalParamField, IntParamField, EventField, EventJsonField, EventFilePath, CtxField, ArgsField)
2. **FnArgument** type — structured function arguments (FromParam(ParamSrc), Ctx, Pi, StringConst, IntConst, NullConst)
3. **HookGuard** type — structured guard conditions (CtxFieldExists, EventFieldExists, NoGuard) — replaces `guard: Option(String)`
4. **Deleted CustomJs(String)** from ResultFormat — no more arbitrary JS injection
5. **Deleted** `lit()`, `from_param()`, `new_arg()`, `custom_js()`, old `FnArg` type

### Verification
- `gleam build` — 0 errors, 0 warnings
- `gleam test` — 109 tests passing
- `generate()` output — verified identical to pre-migration
- `./bin/ppi.mjs` — runs successfully, all 44 tools registered
- A/S dialogue interaction works normally

### Generator Integrity
- **Zero hand-written JS strings** in the entire pipeline
- No `CustomJs` escape hatch — impossible to inject arbitrary JS
- All JS mechanically generated from structured Gleam types

### Key Design Decisions
| Decision | Rationale |
|----------|-----------|
| `??` over `\|\|` | Nullish coalescing correct for empty string defaults |
| `parseInt()` for int params | Pi passes all params as strings |
| `ctx` passed directly | Gleam accesses ctx properties via FFI, not destructuring |
| Tool errors: ctx_notify + return | S-bot sees return value; humans see toast |
| Hook errors: pi.sendMessage | Hooks have no return value; must use persistent message |
| Keep generated extension.js | Static extension.js has Gleam→JS encoding problems (constructor.name, List→Array, Option encoding) |

### Files Modified in This Session
- `src/pi_tool_call.gleam` — core types, HookGuard, deleted CustomJs
- `src/extension_generator.gleam` — registries using HookGuard
- `test/pi_tool_call_test.gleam` — updated for HookGuard, added EventFieldExists test

### Previous Session Changes (still relevant)
- `src/task.gleam`, `skill.gleam`, `memory.gleam`, `learning.gleam` — migrated to FnArgument
- `src/areflect.gleam`, `broadcast.gleam`, `meeting.gleam` — migrated to FnArgument
- `src/monitor_ai.gleam`, `agent_identity.gleam` — migrated to FnArgument
- `src/system_review_tools.gleam`, `issue_tools.gleam`, `code_version.gleam` — migrated to FnArgument

## Build & Deploy
```bash
gleam clean && gleam build
gleam test  # 109 tests
./bin/ppi.mjs  # generates extension.js and starts Pi
```

## Open Issues
- `monitor_ai.gleam:92` — TODO: housekeeping (archive old versions, clean stale config)
