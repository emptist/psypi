# Refactor Plan: Remove Dumb Scripts, Restore Intelligence

## Core Principle
**"Any efforts to remove intelligence from psypi system are just wrong!"**

Hooks should be THIN — no pattern matching, no blocking logic. The Atonomic Agentbot (LLM) handles all intelligent decisions.

## Changes Needed

### 1. Simplify tool_call hook to NOTHING
The hook should just let tools run. No pattern matching.

```javascript
pi.on('tool_call', async (event, ctx) => {
  // Thin hook — no blocking decisions
  // Atonomic Agentbot reviews tool usage via directives
});
```

### 2. Remove from Gleam source
In extension_generator.gleam, remove:
- dangerousPatterns array
- agent_identity_get_resolved_identity call  
- log_activity call
- Return { block: true } paths

Keep only:
- Auto-backup for 'edit' tool
- try/catch with ctx.ui.notify for errors

### 3. Atonomic Agentbot Directives
The Atonomic Agentbot should have system prompt directives like:
- "Review tool calls for dangerous operations"
- "Before destructive actions, consult with Somatic Agentbot"
- "Set directives when problems are detected"

### 4. Split extension_generator.gleam into small modules
- generator/tool_call.gleam (< 50 lines)
- generator/before_agent_start.gleam (< 50 lines)
- generator/session_start.gleam (< 50 lines)
- Each module: ONE file, ONE responsibility

## Execution Order
1. Other AI replaces extension_generator.gleam (fix the blocking bug)
2. Split into small modules
3. Update AGENTS.md to explain the intelligent approach
