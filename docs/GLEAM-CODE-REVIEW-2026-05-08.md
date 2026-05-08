# Gleam Code Review — Deep Analysis (2026-05-08)

Reviewer: AI Code Reviewer
Status: DEEP REVIEW — TS vs Gleam comparison complete

## Build & Test Status

- `gleam build`: ✅ PASS (compiles cleanly)
- `gleam test`: ✅ 46 passed, 0 failures
- **BUT**: Tests only cover decoders and pure functions — NO integration tests for DB/Promise code

---

## 🔴 CRITICAL: Runtime Crashes (Function Signature Mismatches)

These will cause **immediate crashes** when Pi tools are called from extension.js:

| #   | Tool                         | extension.js calls                                           | Gleam function actually expects                                                              | Missing args                    |
| --- | ---------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------- | ------------------------------- |
| 1   | `psypi-skill-build`          | `skill_build(params.name)`                                   | **No `build` function exists!** Only `create(name, description, author)`                     | Function missing entirely       |
| 2   | `psypi-inter-review-show`    | `inter_review_show(params.reviewId)`                         | **No `show` function exists!** Only `get_review()` and `get_review_details()`                | Function missing entirely       |
| 3   | `psypi-broadcast-list`       | `broadcast_list()`                                           | `list(agent_id: Option(String), limit: Int)`                                                 | 2 missing args                  |
| 4   | `psypi-broadcast-send`       | `broadcast_send(params.message)`                             | `send(agent_id, message, priority_str)`                                                      | 2 missing args                  |
| 5   | `psypi-meeting-create`       | `meeting_create(params.title)`                               | `create(topic, created_by)`                                                                  | 1 missing arg                   |
| 6   | `psypi-meeting-add-opinion`  | `meeting_add_opinion(params.meetingId)`                      | `add_opinion(meeting_id, author, perspective, reasoning, position)`                          | 4 missing args                  |
| 7   | `psypi-meeting-complete`     | `meeting_complete(params.meetingId)`                         | `complete(meeting_id, consensus)`                                                            | 1 missing arg                   |
| 8   | `psypi-issue-add`            | `issue_add(params.title)`                                    | `add(title, description, severity, issue_type, created_by)`                                  | 4 missing args                  |
| 9   | `psypi-issue-resolve`        | `issue_resolve(params.issueId)`                              | `resolve(issue_id, resolution)`                                                              | 1 missing arg                   |
| 10  | `psypi-learn`                | `learn(params.content)`                                      | `save(content, tags, importance, agent_id)`                                                  | 3 missing args                  |
| 11  | `psypi-areflect`             | Calls `learning.save()`                                      | Should call `areflect.areflect()`                                                            | Wrong function entirely         |
| 12  | `psypi-inter-review-request` | `inter_review_request(undefined, undefined, undefined, msg)` | `request_review(task_id: Option, commit_hash: Option, reviewer_id: String, context: String)` | reviewer_id passed as undefined |
| 13  | `psypi-skill-list`           | `skill_list()`                                               | `list(status: Option(SkillStatus))`                                                          | Takes enum not no-arg           |

### Root Cause

The `extension_generator.gleam` defines `js_call()` with hardcoded calls that don't match the actual Gleam function signatures. The generator and the modules it calls are **out of sync** — the Gleam modules were written with full parameter lists (matching the DB schema), but the generator was written with minimal params (matching what the Pi tool API exposes).

**Two possible fixes:**
1. Make Gleam functions accept simpler params (provide defaults internally)
2. Make extension.js pass all required params

---

## 🟠 HIGH: Stub / Non-functional Code

| #   | Module          | Problem                                                                                          | Impact                                                                           |
| --- | --------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| 14  | `config.gleam`  | `get_env()` always returns `""` — config is completely non-functional                            | Any code using `get_config()` will always fail with `MissingEnv("DATABASE_URL")` |
| 15  | `db.gleam`      | Hardcoded connection: `postgres@localhost:5432/psypi` — no env var reading                       | Cannot connect to any other DB; no password support                              |
| 16  | `context.gleam` | All functions return hardcoded strings (`"S-psypi-psypi"`, `"P-tencent/hy3-preview:free-psypi"`) | Identity resolution is fake — always returns same values                         |

---

## 🟡 MEDIUM: Code Quality / Bloat / Design Issues

### Redundant Utility Modules (~20+ files)

Many utility modules appear to be duplicated or unnecessary:

| Pair         | Files                                                                                                                                                                                                           | Issue         |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| String utils | `string_ops.gleam` + `string_utils.gleam`                                                                                                                                                                       | Duplicate     |
| Math utils   | `math_ops.gleam` + `math_utils.gleam`                                                                                                                                                                           | Duplicate     |
| Time utils   | `date_utils.gleam` + `time_utils.gleam` + `time_ops.gleam`                                                                                                                                                      | Triplicate!   |
| Validation   | `validation.gleam` + `validation_utils.gleam`                                                                                                                                                                   | Two modules   |
| Config       | `config.gleam` + `config_reader.gleam`                                                                                                                                                                          | Two modules   |
| Error/Result | `error_utils.gleam` + `result_utils.gleam`                                                                                                                                                                      | Overlapping   |
| Data/File    | `data_utils.gleam` + `file_utils.gleam` + `path_utils.gleam`                                                                                                                                                    | Three modules |
| Other        | `cache_utils.gleam`, `log_utils.gleam`, `hash_utils.gleam`, `encoding_utils.gleam`, `bitwise_ops.gleam`, `text_ops.gleam`, `cmd_utils.gleam`, `array_helpers.gleam`, `code_version.gleam`, `package_json.gleam` | Likely unused |

### Dead Code

| File                 | Issue                                            |
| -------------------- | ------------------------------------------------ |
| `hello.gleam`        | Hello world — should be deleted                  |
| `test_backup.gleam`  | Test backup — unclear purpose, should be deleted |
| `skill_loader.gleam` | Overlaps with `skill.gleam`                      |

### FFI Issues

| File                  | Issue                                        |
| --------------------- | -------------------------------------------- |
| `execute_cmd_ffi.mjs` | Uses `require()` — won't work in ESM context |

---

## 🔵 LOW: Style / Consistency

1. **Inconsistent error type naming**: Some modules define their own `ConnectionError`/`QueryError` variants (task, issue, meeting, broadcast, etc.) instead of reusing a shared error type
2. **Inconsistent decoder patterns**: Some use `list.filter_map`, others use `list.fold` + `list.append` for the same task
3. **Missing documentation**: Most public functions lack doc comments
4. **Mixed naming**: `areflect.gleam` vs `inter_review.gleam` — inconsistent naming conventions

---

## Architecture Observations

### What Works Well
- Gleam compiles to clean JS classes with named properties (not arrays) — JS interop for data access works
- `unwrapGleamResult()` in extension.js correctly handles Gleam's `Ok`/`Error` custom types
- The `db.with_connection()` pattern is clean — auto connect/disconnect
- Decoder pattern using `gleam/dynamic/decode` is consistent and testable
- Agent identity is properly split into types/logic/db modules

### What Needs Fixing (Priority Order)
1. **Fix function signature mismatches** — 13 tools will crash at runtime
2. **Implement `get_env()` FFI** — config and db modules are non-functional without it
3. **Add `build` alias to skill.gleam** — or rename in generator
4. **Add `show` alias to inter_review.gleam** — or rename in generator
5. **Delete dead utility modules** — reduce confusion
6. **Fix `psypi-areflect` to call `areflect.areflect()`** — currently calls wrong function

---

## First Gleam Commit

- **Commit**: `2006a1d` — "feat: Gleam integration COMPLETE - modular structure"
- **Date**: May 3, 2026
- **Pre-Gleam commit**: `c852886` — "Fix session ID TWO METHODS support"
- **Observation**: The Gleam integration was introduced as a single massive commit — no incremental migration. This means the TS→Gleam switch was done all-at-once, likely explaining why so many function signatures are mismatched.

---

## TS vs Gleam Comparison

### Tool Inventory: TS had 19 tools, Gleam has 29 tools

#### Tools that SURVIVED from TS → Gleam (with changes)

| TS Tool              | Gleam Tool           | Status                                                                |
| -------------------- | -------------------- | --------------------------------------------------------------------- |
| `psypi-agent-id`     | `psypi-my-id`        | ✅ Renamed, works                                                      |
| `psypi-partner-id`   | `psypi-partner-id`   | ✅ Same, works                                                         |
| `psypi-tasks`        | `psypi-tasks`        | ⚠️ Was no-arg, now takes `status` param                                |
| `psypi-meeting-list` | `psypi-meeting-list` | ⚠️ Was no-arg, now takes `status` param                                |
| `psypi-areflect`     | `psypi-areflect`     | 🔴 BROKEN — calls `learning.save()` instead of `areflect.areflect()`   |
| `psypi-commit`       | `psypi-commit`       | ⚠️ Changed from `execSync('psypi commit')` to `inter_review_request()` |
| `psypi-stats`        | `psypi-stats`        | ✅ Works                                                               |

#### Tools that EXISTED in TS but are MISSING in Gleam

| TS Tool                 | What it did                      | Impact of loss                                       |
| ----------------------- | -------------------------------- | ---------------------------------------------------- |
| `psypi-think`           | External thinker delegation      | ✅ CORRECTLY REMOVED (was "SHIT" per project owner)   |
| `psypi-piSessionID`     | Get session ID (UUID v7)         | 🔴 Lost session tracking — was single source of truth |
| `psypi-autonomous`      | Get guidance for autonomous work | 🔴 Lost autonomous mode — was key feature             |
| `psypi-meeting-say`     | Speak in meeting                 | ⚠️ Replaced by `add-opinion` (different API)          |
| `psypi-meeting-summary` | Get meeting summary              | 🔴 Lost meeting summary capability                    |
| `psypi-meeting-search`  | Search meetings                  | 🔴 Lost meeting search capability                     |
| `psypi-doc-save`        | Save document to DB              | 🔴 Lost document storage                              |
| `psypi-doc-list`        | List documents from DB           | 🔴 Lost document listing                              |
| `psypi-status`          | System status check              | 🔴 Lost status check                                  |
| `psypi-project`         | Project info from git            | 🔴 Lost project context                               |
| `psypi-visits`          | Visit tracking                   | 🔴 Lost visit tracking                                |
| `psypi-sync-inner-ai`   | Sync inner AI model              | 🔴 Lost AI model sync                                 |

#### Tools that are NEW in Gleam (not in TS)

| Gleam Tool                    | Status   | Notes                           |
| ----------------------------- | -------- | ------------------------------- |
| `psypi-agents`                | ✅ Works  | Lists agents — new capability   |
| `psypi-task-add`              | 🔴 BROKEN | Wrong args — needs defaults     |
| `psypi-task-complete`         | ✅ Works  | New capability                  |
| `psypi-skill-build`           | 🔴 BROKEN | Function missing entirely       |
| `psypi-skill-list`            | 🔴 BROKEN | Wrong arg type (enum vs no-arg) |
| `psypi-skill-show`            | ✅ Works  | New capability                  |
| `psypi-skill-search`          | ✅ Works  | New capability                  |
| `psypi-issue-add`             | 🔴 BROKEN | 4 missing args                  |
| `psypi-issue-list`            | ✅ Works  | New capability                  |
| `psypi-issue-resolve`         | 🔴 BROKEN | 1 missing arg                   |
| `psypi-learn`                 | 🔴 BROKEN | 3 missing args                  |
| `psypi-broadcast-send`        | 🔴 BROKEN | 2 missing args                  |
| `psypi-broadcast-list`        | 🔴 BROKEN | 2 missing args                  |
| `psypi-meeting-create`        | 🔴 BROKEN | 1 missing arg                   |
| `psypi-meeting-get`           | ✅ Works  | New capability                  |
| `psypi-meeting-add-opinion`   | 🔴 BROKEN | 4 missing args                  |
| `psypi-meeting-list-opinions` | ✅ Works  | New capability                  |
| `psypi-meeting-complete`      | 🔴 BROKEN | 1 missing arg                   |
| `psypi-validate-commit`       | ✅ Works  | New capability                  |
| `psypi-inter-review-request`  | 🔴 BROKEN | reviewer_id passed as undefined |
| `psypi-inter-reviews`         | ✅ Works  | New capability                  |
| `psypi-inter-review-show`     | 🔴 BROKEN | Function missing entirely       |

### Scorecard: 29 Gleam tools → 12 work, 17 broken (41% success rate)

---

### Architecture Comparison

#### TS Architecture (WORKING — commit c852886)

```
extension.ts → kernel.* → services (full stack)
  ├── kernel.getTasks('PENDING')     → TaskCommands → DatabaseClient
  ├── kernel.meetingSay()            → MeetingHandler → DatabaseClient
  ├── AgentIdentityService           → DatabaseClient + env vars + git + crypto
  ├── BroadcastService               → DatabaseClient + agent filtering + priority
  ├── InterReviewService             → DatabaseClient + AIProvider + EventEmitter
  ├── SkillBuilder                   → generates skills with quality assessment
  ├── kernel.areflect(text)          → parses [LEARN]/[ISSUE]/[TASK] tags
  ├── kernel.piSessionID()           → UUID v7 session tracking
  └── kernel.status()                → full system status
```

Key TS features:
- **Smart defaults**: `kernel.getTasks('PENDING')` just worked — no extra params needed
- **Agent identity**: Real identity resolution via git hash, machine fingerprint, session ID
- **Broadcast filtering**: Agent-aware filtering with priority ordering and read tracking
- **AI-powered review**: InterReviewService used AIProvider for actual code review
- **Skill building**: SkillBuilder generated skills with quality assessment
- **Areflect**: Parsed `[LEARN]`, `[ISSUE]`, `[TASK]` tags from text and saved to appropriate tables
- **Session tracking**: UUID v7 session IDs via `getPiSessionID()`

#### Gleam Architecture (BROKEN — current)

```
extension.js → Gleam modules (direct DB calls)
  ├── task.list(status)              → db.with_connection() → raw SQL
  ├── meeting.create(topic, created_by) → db.with_connection() → raw SQL
  ├── agent_identity                 → hardcoded strings (no real identity)
  ├── broadcast.list(agent_id, limit) → db.with_connection() → raw SQL
  ├── inter_review                   → partial implementation, no AI
  ├── skill                          → no build function at all
  ├── areflect                       → NOT CALLED (learning.save used instead)
  └── config                         → get_env() always returns ""
```

### The Fundamental Architecture Problem

**The Gleam modules were designed around the DATABASE schema (all columns as parameters) rather than around the TOOL API (minimal params, smart defaults from context).**

This is a classic "bottom-up" vs "top-down" design mismatch:

| Aspect                | TS (Top-Down)                           | Gleam (Bottom-Up)               |
| --------------------- | --------------------------------------- | ------------------------------- |
| Design starting point | Tool API → what does the user need?     | DB schema → what columns exist? |
| Function signatures   | Minimal params, smart defaults          | All DB columns as params        |
| Identity              | Resolved internally from env/git/crypto | Hardcoded strings               |
| Config                | Reads from env vars via process.env     | `get_env()` returns `""`        |
| Error handling        | Graceful fallbacks                      | Crashes on missing params       |
| AI integration        | AIProvider for code review              | No AI capability                |

### Specific Feature Regressions

#### 1. Agent Identity (CRITICAL REGRESSION)

**TS**: `AgentIdentityService.getResolvedIdentity()` resolved identity from:
- `process.env.PSYPI_AGENT_SOURCE` / `NEZHA_AGENT_SOURCE`
- Git remote URL → project name
- `git rev-parse --short HEAD` → git hash
- `os.hostname()` + `os.platform()` + `os.arch()` → machine fingerprint
- `crypto.createHash('sha256')` → semantic ID generation
- Session ID via `getPiSessionID()`
- Generated IDs like `S-psypi-psypi-<sessionId>` or `P-tencent/hy3-preview:free-psypi`

**Gleam**: `context.gleam` returns hardcoded strings:
- `agent_id()` → `"S-psypi-psypi"` (always the same)
- `partner_id()` → `"P-tencent/hy3-preview:free-psypi"` (always the same)
- No git integration, no env vars, no crypto, no session tracking

#### 2. Broadcast (MAJOR REGRESSION)

**TS**: `BroadcastService` had:
- Agent-aware filtering (`to_ai = 'all-ais' OR to_ai = $1`)
- Priority ordering (critical → high → normal)
- Read/unread tracking with `markAsRead()`, `markAllAsRead()`
- Unread critical detection
- Broadcast resolution with pattern matching
- Activity logging

**Gleam**: `broadcast.gleam` has:
- Raw `list(agent_id, limit)` — requires agent_id param but extension.js doesn't provide it
- Raw `send(agent_id, message, priority_str)` — requires 3 params, extension.js provides 1
- No read tracking
- No priority ordering
- No activity logging

#### 3. Inter-Review (MAJOR REGRESSION)

**TS**: `InterReviewService` had:
- AI-powered code review via `AIProvider`
- Review findings with severity, file, line, message, suggestion
- Learning extraction from reviews
- Score tracking (overall, code quality, test coverage, documentation)
- Event emission (requested, started, completed, failed)
- Broadcast integration for review notifications

**Gleam**: `inter_review.gleam` has:
- DB storage only — no AI review capability
- No `show` function (extension.js calls `inter_review_show()`)
- No findings, no scores, no learnings
- No event system

#### 4. Skill Builder (MAJOR REGRESSION)

**TS**: `SkillBuilder` had:
- AI-powered skill generation from purpose description
- Quality assessment with scoring
- Skill spec generation (name, description, instructions, triggers, permissions)
- Maintenance tracking (usage count, success rate)

**Gleam**: `skill.gleam` has:
- No `build` function at all
- Only CRUD operations (create, list, get, search)
- No quality assessment
- No AI generation

#### 5. Areflect (BROKEN)

**TS**: `kernel.areflect(text)` parsed `[LEARN]`, `[ISSUE]`, `[TASK]` tags from text and saved to appropriate tables.

**Gleam**: `areflect.gleam` exists with a proper `areflect()` function, but extension.js calls `learning.save()` instead — which requires 4 params but only gets 1.

#### 6. Lost Features (NO GLEAM EQUIVALENT)

These TS features have no Gleam implementation at all:
- `psypi-piSessionID` — session tracking
- `psypi-autonomous` — autonomous work guidance
- `psypi-meeting-summary` — meeting summarization
- `psypi-meeting-search` — meeting search
- `psypi-doc-save` / `psypi-doc-list` — document management
- `psypi-status` — system status
- `psypi-project` — project context
- `psypi-visits` — visit tracking
- `psypi-sync-inner-ai` — AI model sync

---

### Recommended Fix Strategy

**Phase 1: Stop the bleeding (fix runtime crashes)**
1. Add wrapper functions in each Gleam module that accept minimal params and provide defaults
2. Add `skill.build(name)` → delegates to `skill.create(name, "", "system")`
3. Add `inter_review.show(id)` → delegates to `inter_review.get_review(id)`
4. Fix `psypi-areflect` to call `areflect.areflect()` instead of `learning.save()`
5. Fix `psypi-inter-review-request` to provide a default reviewer_id

**Phase 2: Restore lost capabilities**
6. Implement `get_env()` FFI — critical for config and DB
7. Implement real agent identity resolution (git, env vars, crypto)
8. Restore session ID tracking
9. Restore autonomous work guidance
10. Restore document management (doc-save, doc-list)

**Phase 3: Rebuild AI capabilities**
11. Re-implement AI-powered inter-review
12. Re-implement skill building with quality assessment
13. Add broadcast read/unread tracking and priority ordering

**Phase 4: Clean up**
14. Delete dead utility modules (20+ files)
15. Consolidate duplicate utilities
16. Add integration tests for DB/Promise code
17. Fix FFI for ESM context

---

**Next Steps**: Decide on fix strategy with project owner. Phase 1 can be done immediately to stop runtime crashes.
