# Phase 1: Atonomic Agentbot System Prompt Control

## Objective
Enable the Atonomic Agentbot (Monitor) to modify the system prompt that the Somatic Agentbot (Agentbot) receives, creating a continuous work cycle where the Monitor can direct the Agentbot to check issues, tasks, and perform self-improvement.

## Context

### Current Architecture
- **Single Pi TUI session** with both Atonomic and Somatic identities
- **Monitor → Agentbot communication** currently happens via:
  1. DB notifications → `before_agent_start` hook → injects `[MONITOR ALERT]` into system prompt
  2. `tool_result` hook → auto-creates notifications on errors
  3. `psypi-autonomic-consult` tool → LLM-powered advice
- **Problem**: The Atonomic Agentbot has NO direct way to modify the system prompt. It can only create DB notifications (limited, one-shot) or respond to consult requests (reactive, not proactive).

### What Pi Supports (from docs)
The `before_agent_start` event can return:
```javascript
return {
  systemPrompt: event.systemPrompt + "\n\nExtra instructions...",
  message: { customType: "...", content: "...", display: true }
}
```
This is the **official mechanism** for extensions to modify the system prompt per-turn.

### Key Insight
The Atonomic Agentbot needs a **dedicated tool** that writes a "system prompt directive" to the database. The `before_agent_start` hook then reads this directive and injects it into the system prompt. This is the same pattern already used for notifications, but more powerful.

## Issues Found During Testing

### Issue 1: `psypi-task-add` — SQL INSERT missing `project_id`
**Severity**: High  
**File**: `src/task.gleam`  
**Problem**: The `tasks` table has a `project_id` column with a foreign key constraint and RLS policies. The INSERT statement doesn't include `project_id`, which will fail when RLS is enforced or when the column is required.  
**Fix**: Add `project_id` to the INSERT or set a default project.

### Issue 2: `psypi-areflect` — `[TASK] CREATE TABLE` not handled
**Severity**: Medium  
**File**: `src/areflect.gleam`  
**Problem**: The `parse` function only extracts `[LEARN]`, `[ISSUE]`, `[TASK]`, and `[ISSUELIST]` markers. It doesn't handle `[TASK] CREATE TABLE ...` blocks for the reflection workflow. The post-reflection hook (`post_reflection_hook.gleam`) was created but may not be triggered.  
**Fix**: Verify the post-reflection hook is registered and working.

### Issue 3: `psypi-commit` — Review score 0/100
**Severity**: Medium  
**File**: `extension.js` (generated from `psypi_commit_tool()` in `extension_generator.gleam`)  
**Problem**: The commit tool calls the Monitor for review, but the review consistently scores 0/100. Likely the Monitor's system prompt or the review request format doesn't produce parseable output.  
**Fix**: Improve the review prompt format and parsing logic.

### Issue 4: Auto-backup fails for new files
**Severity**: Low  
**File**: `extension.js` → `tool_call` hook  
**Problem**: When `write` tool creates a new file, the auto-backup hook tries to `fs.readFileSync` the file before it exists, causing `ENOENT` error.  
**Fix**: Add a try/catch around the read, or skip backup for `write` tool (file doesn't exist yet).

### Issue 5: Atonomic Agentbot cannot proactively direct Somatic Agentbot
**Severity**: Critical (this is the main task)  
**Problem**: The Atonomic Agentbot has no tool to set persistent system prompt directives. It can only react to `psypi-autonomic-consult` requests or create one-shot DB notifications.  
**Fix**: Create a new `psypi-set-directive` tool and update the `before_agent_start` hook.

## Tasks

### Task 1: Create `psypi-set-directive` Pi tool
**Type**: build  
**Files**: `src/monitor.gleam` (or new `src/directive.gleam`), `src/extension_generator.gleam`  
**Action**: 
- Create a new Gleam function `set_directive(agent_id, directive_text, priority)` that inserts into a new `system_directives` table
- Create a `PiToolCall` value for it
- Register it in `all_tools()`

### Task 2: Create `system_directives` database table
**Type**: build  
**Files**: `src/migrations/005_system_directives.sql`  
**Action**:
- Create table: `id`, `agent_id`, `directive_text`, `priority`, `is_active`, `created_at`, `expires_at`
- Add index on `agent_id` + `is_active`

### Task 3: Update `before_agent_start` hook to read directives
**Type**: build  
**Files**: `src/extension_generator.gleam`  
**Action**:
- After reading notifications, also read active system directives from `system_directives` table
- Inject directives into system prompt with a clear section header
- Mark directives as consumed (or keep them active until expired)

### Task 4: Fix `psypi-task-add` — add `project_id` to INSERT
**Type**: fix  
**Files**: `src/task.gleam`  
**Action**: Add `project_id` parameter to the INSERT query, using a default project lookup.

### Task 5: Fix auto-backup for new files
**Type**: fix  
**Files**: `src/extension_generator.gleam` (the `unified_tool_call_handler_body` function)  
**Action**: Wrap the `fs.readFileSync` in a try/catch, or skip backup for `write` tool.

### Task 6: Fix `psypi-commit` review parsing
**Type**: fix  
**Files**: `src/extension_generator.gleam` (the `psypi_commit_tool()` function)  
**Action**: Improve the review prompt to produce more consistent PASS/SCORE output. Add fallback parsing.

### Task 7: Verify and fix `psypi-areflect` post-reflection hook
**Type**: verify  
**Files**: `src/post_reflection_hook.gleam`, `src/extension_generator.gleam`  
**Action**: Ensure the hook is registered in `all_event_hooks()` and works correctly.

### Task 8: End-to-end test
**Type**: verify  
**Action**: 
- Atonomic Agentbot calls `psypi-set-directive` with "Check for open issues and tasks"
- Somatic Agentbot receives the directive in its system prompt
- Somatic Agentbot acts on the directive

## Verification
- [ ] `psypi-set-directive` tool is available in Pi TUI
- [ ] Directive is injected into system prompt on next turn
- [ ] `psypi-task-add` works without SQL errors
- [ ] Auto-backup doesn't fail for new files
- [ ] `psypi-commit` review produces meaningful scores
- [ ] Full cycle: Atonomic sets directive → Somatic acts on it

## Success Criteria
1. Atonomic Agentbot can proactively set system prompt directives
2. Somatic Agentbot receives and acts on directives
3. No infinite loops (directives are consumed/expired after use)
4. All existing tools continue to work
