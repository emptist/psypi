---
name: pi-platform
description: Pi TUI platform expertise for building extensions, tools, hooks, and skills. Covers Pi SDK, extension development, TUI components, and agent coordination. Use when building psypi extensions, Pi tools, or Pi-related functionality.
---

<essential_principles>
## How Pi Platform Works

Pi is a TUI (Terminal User Interface) that runs "extensions" - code that provides tools, hooks, and skills to the AI agent.

### 1. Pi is the Runtime, Not a Library
Pi executes extensions. You don't "import Pi" - you write code that Pi loads. Extensions respond to events and provide tools.

### 2. Extensions Load from .pi/extensions/
Pi auto-discovers extensions in project's `.pi/extensions/` directory. psypi uses this pattern - `bin/psypi.mjs` spawns `pi` with psypi as working directory.

### 3. Tools are Functions with Context
Pi tools receive `ctx` object with: `ctx.ui.notify()`, `ctx.sessionManager.getSessionId()`, etc. Tools return strings or use UI functions.

### 4. Skills are Modular Knowledge Bases
Skills live in `.pi/skills/` and contain `SKILL.md` (router), `workflows/`, `references/`, `templates/`. Skills auto-load when task matches description.

### 5. ctx.ui.notify() Pattern
All Pi tools should use `ctx.ui.notify()` for output (per Pi docs), not console.log or return strings for complex output.
</essential_principles>

<intake>
What would you like to do with Pi platform?

1. Build a Pi extension
2. Create Pi tools for extension
3. Create a Pi skill
4. Add hooks to extension
5. Debug Pi extension/tool
6. Use Pi SDK (createAgentSession, etc.)
7. Something else

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| 1, "extension", "build extension" | `workflows/build-extension.md` |
| 2, "tool", "pi tool", "add tool" | `workflows/create-pi-tool.md` |
| 3, "skill", "create skill" | Route to create-agent-skills skill |
| 4, "hook", "add hook" | `workflows/add-hook.md` |
| 5, "debug", "broken", "fix" | `workflows/debug-extension.md` |
| 6, "sdk", "agent session", "createAgent" | `workflows/use-pi-sdk.md` |
| 7, other | Clarify, then route |
</routing>

<reference_index>
## Domain Knowledge

All in `references/`:

**Architecture:** pi-architecture.md, extension-structure.md, ctx-object.md
**Tools:** tool-pattern.md, ctx-ui-notify.md, tool-best-practices.md
**Skills:** skill-structure.md, skill-router-pattern.md, skill-workflows.md
**SDK:** pi-sdk.md, create-agent-session.md, agent-events.md
**TUI:** tui-components.md, tui-layout.md (from Pi docs/tui.md)
**Events:** hooks.md, event-types.md, event-handling.md
**Anti-patterns:** what-not-to-do.md, common-mistakes.md
</reference_index>

<workflows_index>
## Workflows

All in `workflows/`:

| File | Purpose |
|------|---------|
| build-extension.md | Create Pi extension from scratch |
| create-pi-tool.md | Add tool to existing extension |
| add-hook.md | Add event hook to extension |
| debug-extension.md | Debug Pi extension issues |
| use-pi-sdk.md | Use Pi SDK for agent sessions |
</workflows_index>
