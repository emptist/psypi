# Phase 2: Autonomic Agentbot First Entry

## Objective
Enable the Autonomic Agentbot (A-) to wake up, display marked messages, and perform its first real action.

## Topic 1: Visual Distinction — How to tell A-agentbot from S-agentbot

### Problem
Both agentbots can display messages on screen. The S-agentbot (current AI) needs to know when a message comes from the A-agentbot.

### Solution: `[Autonomic]` prefix on A-agentbot messages

**Only the A-agentbot needs a mark.** The S-agentbot already knows who it is.

Implementation:
1. When the A-agentbot uses `pi.sendMessage()` or `ctx.ui.notify()`, prefix with `[Autonomic]`
2. The `customType` field can be set to `'autonomic-message'` for TUI styling
3. No mark needed on S-agentbot messages (they're the default)

**Where to implement:**
- In the `before_agent_start` hook: when injecting directives, add `[Autonomic]` prefix
- In any A-agentbot tool output: prefix with `[Autonomic]`
- In meeting opinions created by A-agentbot: prefix with `[Autonomic]`

### Verification
- [ ] A-agentbot messages show `[Autonomic]` prefix on screen
- [ ] S-agentbot messages have no prefix (default)
- [ ] Both agentbots can read each other's messages

## Topic 2: First Entry Point — Where does the A-agentbot first appear?

### Problem
The A-agentbot is event-driven. It needs a trigger to wake up and do something real. Currently, hooks just inject directives but the A-agentbot never actually runs.

### Solution: `before_agent_start` creates a "boot directive" if none exist

**The `before_agent_start` hook should:**
1. Check if there are any active directives
2. If NO directives exist, create a boot directive: `"[Autonomic] System boot: Assess system health, check for failed tasks and open issues, then set directives for the Somatic Agentbot."`
3. The S-agentbot receives this directive in its system prompt
4. The S-agentbot acts on it — but wait, that's wrong. The **A-agentbot** should act on it.

**Better approach: The A-agentbot wakes up via `session_start`**

The `session_start` hook fires when a session starts. This is the natural entry point:
1. `session_start` hook runs
2. It checks system health (already does this)
3. If health issues found, it creates a directive AND uses `pi.sendMessage()` to display an `[Autonomic]` message
4. The A-agentbot's first message appears on screen: `[Autonomic] System check: 3 failed tasks, 5 open issues. Directing Somatic Agentbot to investigate.`

### First Real Action Sequence

```
1. Session starts → session_start hook fires
2. Hook checks system health (failed_tasks, open_issues)
3. If issues found:
   a. Creates directive: "Investigate 3 failed tasks and 5 open issues"
   b. Displays: "[Autonomic] Detected issues: 3 failed tasks, 5 open issues"
4. before_agent_start hook reads directive, injects into system prompt
5. Somatic Agentbot receives directive, acts on it
6. Somatic Agentbot reports back via psypi-autonomic-consult or meetings
```

### Implementation Steps

#### Step 1: Update `session_start` hook to display Autonomic messages
- After checking health, if issues found, use `ctx.ui.notify()` with `[Autonomic]` prefix
- Also create a directive for the Somatic Agentbot

#### Step 2: Update `before_agent_start` to show Autonomic prefix
- When injecting directives, add `[Autonomic]` prefix to the directive text
- This way the Somatic Agentbot sees: `[Autonomic] Investigate 3 failed tasks`

#### Step 3: Create a dedicated `psypi-autonomic-status` tool
- Only the A-agentbot uses this
- Returns system health + recent activity
- Output prefixed with `[Autonomic]`

### Verification
- [ ] Session start shows `[Autonomic]` message if issues detected
- [ ] Directives in system prompt show `[Autonomic]` prefix
- [ ] Somatic Agentbot can read and act on Autonomic directives
- [ ] No infinite loop (directives are consumed after injection)

## Files to Modify

| File                                     | Change                                                     |
| ---------------------------------------- | ---------------------------------------------------------- |
| `src/generator/session_start.gleam`      | Add health-based message display with `[Autonomic]` prefix |
| `src/generator/before_agent_start.gleam` | Add `[Autonomic]` prefix to injected directives            |
| `src/extension_generator.gleam`          | Add `psypi-autonomic-status` tool registration             |

## Implementation Status
- [x] `session_start` hook displays `[Autonomic]` message if issues detected
- [x] `before_agent_start` hook adds `[Autonomic]` prefix to injected directives
- [x] `psypi-direct-agentbot` tool renamed (only A-agentbot uses it)
- [x] Build and regeneration successful
- [ ] Waiting for psypi restart to test

## Success Criteria
1. A-agentbot shows `[Autonomic]` marked messages on screen
2. S-agentbot can clearly distinguish A-agentbot messages
3. A-agentbot wakes up on session start and displays first message
4. Directive communication channel works end-to-end
5. No infinite loops or message flooding
