# Psypi Code Review - Is It on the Right Way to Enhance Pi?

## Executive Summary

**Psypi has good intentions but critical architectural flaws.** The most fundamental issue is **session ID handling**, which misunderstands how Pi and CLI processes interact. The project also has contradictory rules and an incomplete migration from "fake AI" to real Pi agent integration.

**Key Clarification (User Insight):**
- **`psypi` (no args)** = Main use case (runs as daemon/service or interactive mode)
- **`psypi <command>`** = Historical/legacy CLI commands, OR commands meant to be used **inside** a running psypi instance
- **These commands should be replaced by Pi agent tools** (the extension tools like `psypi-tasks`, `psypi-think`, etc.)

---

## 🔴 Critical Issues

### 1. Session ID Handling is Fundamentally Broken

**The Problem:**
- `session.ts` (kernel utility) reads `process.env.AGENT_SESSION_ID`
- `extension.ts` (Pi extension) sets `process.env.AGENT_SESSION_ID` in `session_start` event
- **BUT**: The Pi extension runs inside Pi's process, while `psypi <command>` CLI runs as a **separate process**

**Why This Breaks:**
```bash
# Pi process (sets AGENT_SESSION_ID in its own process memory)
pi (process A)
  └─ psypi extension loaded
       └─ session_start fires, sets process.env.AGENT_SESSION_ID = "abc-123"

# CLI process (does NOT inherit Pi's process.env!)
psypi my-session-id (process B)
  └─ session.ts reads process.env.AGENT_SESSION_ID → undefined!
```

**The Contradiction in AGENTS.md:**
> "NEVER DO THESE (WRONG): Direct access: `process.env.AGENT_SESSION_ID`"

> "Method 1: Check environment variable (set by Pi TUI)" ← **This contradicts the rule above!**

**The Correct Approach (per Pi docs):**
- **In Pi extension**: Use `ctx.sessionManager.getSessionId()` ✅
- **In CLI (separate process)**: Generate your own ID or accept that you don't have Pi's session ID
- **`psypi <command>` commands are legacy** - they shouldn't need Pi's session ID anyway!

**Verdict**: The "ONE SINGLE WAY" (`kernel.piSessionID()`) is trying to bridge two separate processes via environment variables, which **does not work**. But since `psypi <command>` are legacy, this might not matter if they're being replaced by Pi tools.

---

### 2. Process Isolation Misunderstanding

**What Psypi Assumes:**
```
Pi TUI → sets AGENT_SESSION_ID → psypi CLI can read it
```

**Reality:**
```
Pi TUI (Process A) → sets process.env.AGENT_SESSION_ID
                        └─ Child processes inherit THIS, but...
psypi CLI (Process B) → Separate process, different memory space
```

**When WOULD it work?**
Only if `psypi <command>` is called FROM Pi (e.g., via `bash` tool):
```typescript
// Pi tool call
bash("psypi my-session-id")  // Child process INHERITS Pi's process.env
```

**But the user says:** `psypi <command>` are **historical/legacy** and should be replaced by Pi agent tools anyway!

**Verdict**: Session ID issue is moot if legacy CLI commands are being replaced by Pi extension tools.

---

### 3. Contradictory Documentation

**AGENTS.md says:**
> "⚠️ Mandatory Session ID Rule: Single entry point: `kernel.piSessionID()` is the ONLY way"

> "No direct access: Never use `process.env.AGENT_SESSION_ID` directly"

**But session.ts DOES:**
```typescript
// src/kernel/utils/session.ts
export function getPiSessionID(): string {
  // Method 1: Check environment variable (set by Pi TUI) ← VIOLATES THE RULE!
  const envSessionID = process.env.AGENT_SESSION_ID;
  if (envSessionID) {
    return envSessionID;  // ← DIRECT ACCESS!
  }
  // ...
}
```

**Verdict**: The code violates its own rules. But again, if `psypi <command>` are legacy, this might not matter.

---

## 🟡 Architectural Concerns

### 4. The Gleam/TypeScript Split

**The Idea:** "Small + Pure = Resilience" (Gleam modules < 100 lines)

**The Reality:**
- **Gleam CLI** → Compiles to JavaScript, uses FFI to call TypeScript
- **TypeScript Extension** → Runs in Pi's process
- **FFI Bridge** → `review.gleam` → `review_ffi.mjs` → TypeScript

**Pros:**
- Gleam's type safety for CLI
- Clear separation of concerns

**Cons:**
- FFI bridging adds complexity
- Debugging across language boundaries is harder
- Two languages to maintain
- **If `psypi <command>` are legacy, why keep Gleam CLI?**

**Verdict**: Interesting experiment, but if replacing CLI commands with Pi tools, the Gleam CLI might be unnecessary.

---

### 5. "God in the Sky" / Monitor Concept

**The Idea:** A permanent AI reviewer ("God") that reviews all commits via `psypi commit`

**Current Implementation:**
- `review.gleam` → FFI → JavaScript → "fake" stateless API
- README says: "Inner AI: ⚠️ Working but fake (stateless API - to be replaced with real Pi agent)"

**The Problem:**
The "God" is currently fake. The README notes:
> "Next Major Step: Replace fake inner AI with real Pi agent via `createAgentSession()`"

**Verdict**: Good concept, incomplete implementation. Should use Pi SDK to create a real agent.

---

### 6. Over-Engineered Rules

**AGENTS.md has 15+ "NEVER DO THIS" rules:**
- Never use `process.env.AGENT_SESSION_ID`
- Never cache in variables
- Never use `git commit` (must use `psypi commit`)
- Never bypass psypi tools with `psql`
- ...

**The Problem:**
Too many restrictive rules suggest the system is fighting against AI behavior rather than working with it. A well-designed system should make the right thing easy and the wrong thing hard, not rely on lengthy rule lists.

**Verdict**: Simplify. If AIs keep doing "evil" things, fix the tool design, not the rules.

---

## 🟢 What Psypi Does RIGHT

### 7. Using Pi's Extension System Correctly

**The Pi extension (`extension.ts`) correctly:**
- Uses `pi.on("session_start", ...)` to hook into Pi events ✅
- Uses `ctx.sessionManager.getSessionId()` to get session ID ✅
- Registers tools via `pi.registerTool()` ✅
- Uses `ctx.ui.notify()` for user feedback ✅

**Verdict**: This part is well done. The Pi extension tools (like `psypi-tasks`, `psypi-agent-id`) are the RIGHT way to expose psypi functionality to Pi's LLM.

---

### 8. The "Small Modules" Philosophy

**Gleam modules are indeed small:**
- `cli.gleam`: ~60 lines
- `review.gleam`: ~15 lines
- `partner.gleam`: ~20 lines

**Verdict**: Good for maintainability, though the FFI bridging complicates the benefit.

---

## 📋 Recommendations

### Understand the Real Architecture (Priority 1)

**Based on user clarification:**
```
Pi (main AI runtime)
  └─ psypi extension (runs inside Pi's process)
       └─ Registers tools: psypi-tasks, psypi-think, psypi-agent-id, etc.
       └─ These tools are called by Pi's LLM

psypi (no args) - Main use case
  └─ Possibly starts interactive mode or daemon?
  └─ Should use Pi SDK internally?

psypi <command> - Legacy/Historical
  └─ Should be replaced by Pi extension tools
  └─ Don't need Pi's session ID (different context)
```

**Action**: Document this architecture clearly. The session ID issue is moot for legacy CLI commands.

---

### Complete Pi Agent Integration (Priority 2)

**Current State:** "Inner AI: Working but fake"

**Needed:**
```typescript
// Replace fake AI in src/agent/extension/extension.ts
import { createAgentSession } from "@mariozechner/pi-coding-agent";

async function createInnerAgent() {
  const { session } = await createAgentSession({
    model: getModel("anthropic", "claude-opus-4-5"),
    // ...
  });
  return session;
}
```

**Note**: The "God in the sky" should be a REAL Pi agent, not a fake API. Use Pi SDK.

---

### Remove Legacy CLI Commands (Priority 3)

Since `psypi <command>` are historical and should be replaced by Pi tools:

1. **Keep**: `psypi` (no args) - main entry point
2. **Deprecate**: `psypi task-add`, `psypi issue-add`, etc.
3. **Replace with**: Pi extension tools (`psypi-tasks`, `psypi-think`, etc.)

**Benefit**: No more session ID confusion - everything runs inside Pi's process!

---

### Simplify Documentation (Priority 4)

**Replace 15+ "NEVER" rules with:**
1. Clear examples of correct usage
2. Tool design that makes correct usage obvious
3. Remove contradictory rules (e.g., "never use AGENT_SESSION_ID" but then use it in session.ts)

**New approach:**
```
Pi Extension Tools (run inside Pi):
  ✅ Use ctx.sessionManager.getSessionId()
  ✅ Registered via pi.registerTool()
  ✅ Called by Pi's LLM

psypi CLI (separate process):
  ⚠️ Legacy/historical commands
  ⚠️ Don't need Pi's session ID
  🎯 Being replaced by Pi tools anyway
```

---

## 🎯 Final Verdict: Is Psypi on the Right Way?

### Yes, partially:
- ✅ Using Pi's extension system correctly (the Pi tools are the right approach)
- ✅ Good concept (AI coordination system with "God" reviewer)
- ✅ Gleam for "small, unbreakable" modules (though may be unnecessary if replacing CLI)

### No, critical issues:
- ❌ Session ID handling is confused (but moot if replacing CLI commands)
- ❌ Contradictory rules and documentation
- ❌ "Fake" inner AI needs replacement with real Pi agent
- ❌ Over-engineered rules instead of good tool design
- ❌ Gleam CLI might be unnecessary if `psypi <command>` are legacy

### Grade: **B-** (Better than C+ after user clarification)

**Why B-?**
- The core approach (Pi extension tools) is correct ✅
- The session ID issue is moot if legacy CLI is being replaced ✅
- Still needs: real Pi agent for "God", simplified docs, clearer architecture

**To get to A-:**
1. **Remove legacy CLI commands** (or mark as deprecated)
2. **Replace fake AI with real Pi agent** via `createAgentSession()`
3. **Document architecture clearly**: Pi extension tools = RIGHT way; CLI commands = legacy
4. **Simplify rules**: Less "NEVER", more "Here's how to do it correctly"

---

## 📝 Appendices

### A. Testing the Session ID Claim

```bash
# Check if AGENT_SESSION_ID is set
echo $AGENT_SESSION_ID
# Output: (empty)

# Check if psypi CLI can access it
psypi my-session-id
# Output: Error: AGENT_SESSION_ID not set. Pi TUI must be running.

# But Pi TUI IS running! The issue is process isolation.
# HOWEVER: psypi <command> are legacy anyway, so this doesn't matter!
```

### B. Key Files Reviewed

| File | Issue |
|------|-------|
| `src/kernel/utils/session.ts` | Reads `AGENT_SESSION_ID` directly (violates own rules) |
| `src/agent/extension/extension.ts` | Sets `AGENT_SESSION_ID` (only works in Pi's process) ✅ |
| `AGENTS.md` | Contradictory rules about session ID |
| `gleam/psypi_core/src/psypi_core/review.gleam` | Uses fake AI (to be replaced) |
| `README.md` | Documents "fake" inner AI problem |

### C. Real Architecture (User Clarified)

```
MAIN USE CASE:
$ psypi (no args)
  └─ Runs as daemon/service or interactive mode
  └─ Uses Pi internally? Or separate?

LEGACY/HISTORICAL:
$ psypi <command>
  └─ task-add, issue-add, etc.
  └─ Should be replaced by Pi extension tools
  └─ Don't need Pi's session ID (see pi-session-id-truth.md)

RIGHT WAY (Pi Extension Tools):
Pi LLM calls: psypi-tasks, psypi-think, psypi-agent-id, etc.
  └─ These run inside Pi's process
  └─ Can access ctx.sessionManager.getSessionId() ✅
  └─ This is the FUTURE of psypi integration
```

**Note**: For the full explanation of why `process.env.AGENT_SESSION_ID` doesn't work and the correct approaches, see `pi-session-id-truth.md` in this directory.

### D. References

- **Pi Session ID Truth**: `pi-session-id-truth.md` (in this same `docs/` directory) — Definitive proof that `process.env.AGENT_SESSION_ID` is an illusion and guide to correct session ID access methods
- Pi Extension API: `packages/coding-agent/src/core/extensions/types.ts` (pi-mono)
- Pi SessionManager: `packages/coding-agent/src/core/session-manager.ts` (pi-mono)

**See Also**: The companion document `pi-session-id-truth.md` provides the complete technical analysis of session ID handling in Pi, including verification that `AGENT_SESSION_ID` environment variable does not exist in Pi's codebase.
