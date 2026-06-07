# Refactor Notes — 2026-05-14

## What Was Done

### Problem
- `extension_generator.gleam` was 550 lines — too big, edits kept failing
- Old code accumulated because partial edits appended rather than replaced
- `tool_call` hook had dangerous pattern matching that blocked file writes based on content
- Identity resolution and activity logging crashed silently, blocking all tools

### Solution
Split into small, focused modules (< 100 lines each):

| Module                               | Lines | Purpose                                            |
| ------------------------------------ | ----- | -------------------------------------------------- |
| `generator/tool_call.gleam`          | 31    | Thin hook — auto-backup only, no blocking          |
| `generator/before_agent_start.gleam` | 36    | Read directives from DB, inject into system prompt |
| `generator/session_start.gleam`      | 20    | Session init — record model, check health          |
| `generator/model_select.gleam`       | 19    | Record model changes                               |
| `generator/tool_result.gleam`        | 34    | Detect errors, create directives                   |
| `generator/agent_lifecycle.gleam`    | 20    | Agent start/end silent logging                     |
| `extension_generator.gleam`          | 318   | Composes all modules                               |

### Key Changes
1. **Removed dangerous pattern matching** — no more blocking file writes based on content
2. **Removed identity resolution from hook** — was crashing silently
3. **Removed activity logging from hook** — was crashing silently
4. **Hook is now thin** — just auto-backup for 'edit' tool
5. **Atonomic Agentbot handles safety intelligently** — via directives, not scripts

### Build Status
- ✅ `gleam build` — success
- ✅ `gleam run -m extension_generator` — success
- ⏳ Waiting for psypi restart to test tools

### Next Steps
1. Restart psypi and test all tools
2. If tools work, continue splitting remaining large files
3. Target: all Gleam files < 100 lines

---

## FnArgument Migration & Documentation Cleanup — 2026-06-07

### What Was Done

#### 1. Code Comment Cleanup

Removed stale references to deleted types from source code:

| File | Change |
|------|--------|
| `src/pi_tool_call.gleam` | Removed "OLD FnArg" and "replace old FnArg + JsLiteral + FromParam" comments |
| `src/pi_tool_call.gleam` | Removed "replaces JsLiteral + FromParam(String)" from FnArgument doc comment |
| `src/agent_identity.gleam` | Removed "via JsLiteral" from doc comment |
| `AGENTS.md` | Replaced `lit()`, `from_param()` with `param()`, `opt_param()`, `str()`, `int_val()` |

#### 2. Skill Documentation Rewrite (ppi_skills/gleam-pi-tool-generator/)

Rewrote all reference and workflow docs to use new structured types:

| File | Action |
|------|--------|
| `references/fn-arg.md` | **Deleted** — replaced by fn-argument.md |
| `references/fn-argument.md` | **New** — FnArgument + ParamSrc structured types |
| `references/hook-guard.md` | **New** — HookGuard type reference |
| `references/result-format.md` | **Rewritten** — RawJson + Template only, CustomJs deleted |
| `references/pi-toolcall-type.md` | **Rewritten** — complete PiToolCall reference |
| `references/pi-eventhook-type.md` | **Rewritten** — PiEventHook + PiDebouncedHook |
| `references/type-mapping.md` | **Rewritten** — Gleam types → compiled JS classes |
| `references/architecture.md` | **Rewritten** — generator architecture, zero-JS principle |
| `workflows/add-new-tool.md` | **Rewritten** — uses structured constructors only |
| `workflows/modify-tool.md` | **Rewritten** — no lit/from_param/custom_js |
| `workflows/add-event-hook.md` | **Rewritten** — HookGuard instead of Option(String) |
| `workflows/debug-generation.md` | **Rewritten** — common problems table updated |

#### 3. Zero-Handwritten-JS Skill Updated

Added "Lessons Learned" section to `.trae/skills/zero-handwritten-js/SKILL.md`:
- The journey from FnArg/JsLiteral to structured types
- Key insights: type-driven > string templating, delete escape hatches aggressively
- Three-layer model (FFI / Generator / Business Logic)
- What to do when you need a new JS pattern

#### 4. Standalone Documentation Created

| File | Action |
|------|--------|
| `docs/ZERO-HANDWRITTEN-JS.md` | **New** — standalone experience summary for external readers, linked from README |

Content: three-layer architecture, ParamSrc/FnArgument/HookGuard/ResultFormat mapping tables, complete tool definition example, deleted types reference, lessons learned, new JS pattern workflow, verification checklist.

#### 5. README Updated

Added `Documentation` section at the end with links to: AGENTS.md, ZERO-HANDWRITTEN-JS.md, REFACTOR-NOTES.md, CURRENT-STATE.md, HANDOVER.md, docs/.

#### 6. AGENTS.md Condensed

801 lines → 286 lines (64% reduction). Removed:
- Duplicate PDCA tables (appeared 3 times)
- Full A-bot/S-bot job list snapshots (DB is source of truth)
- Reference Materials directory listing (not agent-relevant)
- Verbose inter-review vs system-review comparison table
- Detailed `save_soul_version()` SQL function body

Retained all critical info: Quick Start, Architecture, Database, Identity, A/S Model, 44 tools, Commit Workflow, Critical Rules, Lessons Learned.

### Verification

- `gleam clean && gleam build` — success
- `gleam test` — 109 passed, 0 failures
- No `lit()`, `from_param()`, `JsLiteral`, `CustomJs` in `.gleam` source code
- Remaining references in docs/ are historical review records (not modified)
