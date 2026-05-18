# Doc Audit: Post-May 17 Documentation vs. Codebase Reality

**Date:** 2026-05-18
**Auditor:** OWL (S-agentbot)
**Scope:** All docs created/modified after 2026-05-17

---

## Documents Reviewed

| #   | File                           | Type                |
| --- | ------------------------------ | ------------------- |
| 1   | `docs/ARCHITECTURE.md`         | Design vision       |
| 2   | `docs/AGENT-IDENTITY-FINAL.md` | Design proposal     |
| 3   | `docs/AS-COMMUNICATION.md`     | Architecture doc    |
| 4   | `docs/AGENT-END-PLAN.md`       | Implementation plan |
| 5   | `docs/GENERATOR-AUDIT.md`      | Audit + plan        |
| 6   | `docs/MONITOR-DEBOUNCE.md`     | Config doc          |
| 7   | `docs/TOOL-TEST-RESULTS.md`    | Test results        |
| 8   | `docs/TOOL-TEST-PLAN.md`       | Test plan           |
| 9   | `PLAN-PSYPI-MODE.md`           | Feature plan        |

---

## Detailed Findings

### 1. `docs/ARCHITECTURE.md` — ❌ Describes future state, not current code

**Claims:**
- Pure `Context` type with fields `is_idle`, `model_id`, `provider`, `thinking_level`, `cwd`
- Single-argument `get_resolved_identity(ctx: Context)` function
- "No More JS Strings" — `ctx.model_id` is a "Pure Gleam field"
- `agent_end.gleam` and `autonomic_hooks.gleam` as current implementation files
- Each file < 100 lines

**Reality:**
- No `Context` type exists in any Gleam module
- `agent_identity.gleam` line 15: `get_resolved_identity(autonomous, project, source, model, thinking_level, global)` — **6 separate arguments**
- `agent_identity_logic.gleam` line 19: `generate_semantic_id(autonomous, project, source, model, thinking_level, global)` — **6 separate arguments**
- JS expression strings like `"(ctx.model?.id || '')"` still passed as `lit()` values
- `context.gleam` exists but only has stubs (`my_id()` returns `"S-psypi-psypi-unknown"`)
- `agent_end.gleam` and `autonomic_hooks.gleam` do **not exist** — implementation is in `generator/agent_end_coordination.gleam`

**Verdict:** Aspirational redesign, not current state.

---

### 2. `docs/AGENT-IDENTITY-FINAL.md` — ❌ Design proposal, not implemented

**Claims:**
- "One function signature" — no more 6 arguments
- `Context` type with `is_idle`, `model_id`, `provider`, `thinking_level`, `cwd`
- `get_resolved_identity(ctx: Context)` — one argument
- Call sites construct a `Context` value and pass it

**Reality:**
- Same as above — no `Context` type, 6-arg functions still in use
- All call sites in `agent_identity.gleam` pass 6 literal/function-call args

**Verdict:** Design proposal awaiting implementation.

---

### 3. `docs/AS-COMMUNICATION.md` — ⚠️ Conceptually correct, file references wrong

**Claims:**
- A/S dual-agentbot model with `get_resolved_identity` as single source of truth
- `agent_end.gleam` implements the coordination
- `autonomic_hooks.gleam` contains simple hooks
- Each file under 100 lines
- Debounce configurable via `system_config` table

**Reality:**
- A/S model description is **correct** and matches the running code
- `agent_end.gleam` does **not exist** — actual file is `generator/agent_end_coordination.gleam`
- `autonomic_hooks.gleam` does **not exist**
- `generator/agent_end_coordination.gleam` is ~80 lines ✓
- `system_config` table reference is correct (used in the coordination handler)

**Verdict:** Right architecture, wrong file paths.

---

### 4. `docs/AGENT-END-PLAN.md` — ✅ Accurate plan, not yet executed

**Claims:**
- Current `handler_body()` functions return hardcoded JS strings
- Proposes structured `PiEventHook` with `SimpleHook`/`ComplexHook` variants
- Proves each fake generator file maps to a structured `PiEventHook` value
- Lists exact files to modify/delete

**Reality:**
- Analysis is correct — `pi_tool_call.gleam` line 64-67 still shows `PiEventHook(event_name: String, handler_body: String)`
- `generator/` directory still exists with all 7 files
- No `SimpleHook`/`ComplexHook` variants exist
- The plan is internally consistent and detailed

**Verdict:** Correct analysis, plan not executed.

---

### 5. `docs/GENERATOR-AUDIT.md` — ✅ Accurate analysis, plan not executed

**Claims:**
- `handler_body()` functions are "string concatenation machines" with hand-coded JS
- Proposes changing `PiEventHook` to have `module`/`fn_name`/`args` fields
- Maps each hook to a target Gleam module (session_start → monitor, tool_call → code_version, etc.)
- Proposes deleting all 7 `generator/` files

**Reality:**
- Analysis is accurate — `session_start.gleam` handler_body returns a hardcoded JS string with `record_current_model` embedded
- `PiEventHook` type (line 64 of `pi_tool_call.gleam`) still has `handler_body: String`
- No `module`/`fn_name`/`args` fields exist
- `generator/` directory still has all 7 files

**Verdict:** Accurate audit, plan not executed.

---

### 6. `docs/MONITOR-DEBOUNCE.md` — ⚠️ Mostly accurate, "default" claim misleading

**Claims:**
- Key: `monitor_debounce_ms` in `system_config` table
- Default: 15000ms (15 seconds)
- Lists example values (15000, 60000, 120000)
- Describes debugging for failed wake-up messages

**Reality:**
- `agent_end_coordination.gleam` line 24: reads `monitor_debounce_ms` from `system_config` ✓
- **No default fallback** — line 30: `throw new Error('monitor_debounce_ms not found or invalid')`
- The code will crash if the key is missing, not fall back to 15000ms
- `MONITOR-BRIEF.md` also claims "default 15000ms" but this isn't implemented in code

**Verdict:** Doc is misleading — there is no default, the code throws on missing config.

---

### 7. `docs/TOOL-TEST-RESULTS.md` — ✅ Accurate reflection of real bugs

**Summary:** 35 tools tested
- 9/35 work with useful output
- 12/35 work but return unusable raw JSON
- 8/35 are broken (errors)
- 6/35 partially working

**Verified bugs match code reality:**
| Tool                      | Reported Error                        | Code Evidence                                      |
| ------------------------- | ------------------------------------- | -------------------------------------------------- |
| `psypi-issues`            | "there is no parameter $0"            | SQL binding issue in issue module                  |
| `psypi-clear-directives`  | "column 'active' does not exist"      | Code references `active` but table has `is_active` |
| `psypi-memory-search`     | Returns literal `{count}`             | Template `"Count: {count}"` not interpolated       |
| `psypi-issue-count`       | Returns "Count: 0"                    | Issue counting logic flawed                        |
| `psypi-learn-save`        | "Cannot read properties of undefined" | Missing/null function crash                        |
| `psypi-skill-search`      | Returns empty `{}`                    | Search not working                                 |
| `psypi-commit`            | Scores 0/100                          | Score parsing regex issue                          |
| `psypi-consult-autonomic` | Minimal output                        | Monitor LLM responds but output thin               |

**Root causes identified match code:**
1. Raw JSON output — most tools use `result_format: raw_json()` returning unformatted DB records
2. DB schema mismatches — column names in code don't match actual table schemas
3. Broken templates — literal `{count}` not interpolated
4. SQL binding errors — parameter numbering issues
5. Missing required params — tool definitions don't match DB requirements

**Verdict:** Accurate test results. All bugs are real and traceable to code.

---

### 8. `docs/TOOL-TEST-PLAN.md` — ✅ Complete and accurate

Lists 35 tools across 18 categories. Matches `all_tools()` in `extension_generator.gleam`.

**Verdict:** Complete and accurate.

---

### 9. `PLAN-PSYPI-MODE.md` — ❌ Incomplete, not implemented

**Claims:**
- Proposes `normal`/`minimal` modes stored in Pi settings under `psypiMode`
- `normal` loads all skills + AGENTS.md + full tool list
- `minimal` keeps only `read` and `bash`
- Plans `psypi_mode.gleam` helper module
- Plans slash command `/mode` to switch modes

**Reality:**
- `psypi_mode.gleam` does **not exist**
- No mode-aware prompt building in `extension_generator.gleam`
- No `/mode` command registered
- The doc itself is **incomplete** — code snippet cuts off mid-function

**Verdict:** Incomplete plan, not implemented.

---

## Summary Table

| Doc                       | Accuracy                    | Status        |
| ------------------------- | --------------------------- | ------------- |
| `ARCHITECTURE.md`         | ❌ Future state, not current | Aspirational  |
| `AGENT-IDENTITY-FINAL.md` | ❌ Not implemented           | Proposal      |
| `AS-COMMUNICATION.md`     | ⚠️ Right idea, wrong paths   | Outdated refs |
| `AGENT-END-PLAN.md`       | ✅ Accurate analysis         | Not executed  |
| `GENERATOR-AUDIT.md`      | ✅ Accurate analysis         | Not executed  |
| `MONITOR-DEBOUNCE.md`     | ⚠️ Misleading "default"      | Minor issue   |
| `TOOL-TEST-RESULTS.md`    | ✅ Accurate                  | Real bugs     |
| `TOOL-TEST-PLAN.md`       | ✅ Accurate                  | Complete      |
| `PLAN-PSYPI-MODE.md`      | ❌ Incomplete                | Not started   |

---

## Key Takeaway

The post-May 17 docs describe **two distinct layers**:

1. **Accurate analysis layer** — Tool test results and bug reports correctly identify real issues in the running code. The generator audit and agent-end plan correctly diagnose architectural problems.

2. **Aspirational redesign layer** — The `Context` type, single-argument `get_resolved_identity`, structured `PiEventHook`, deleted `generator/` directory, and `psypi_mode` are **design proposals that have NOT been implemented**. The codebase still runs the old 6-argument signatures, the `generator/` directory still exists with hardcoded JS strings, and no `Context` type exists anywhere.

The docs do not clearly distinguish between "what is" and "what should be," which could mislead a reader (or an AI agent) into believing the redesigned architecture is already in place.
