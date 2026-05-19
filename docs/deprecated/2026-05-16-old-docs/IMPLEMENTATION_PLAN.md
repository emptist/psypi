# Implementation Plan: Unified Event Interception Pipeline

## Overview
Unify the generic activity logging and the specialized auto-backup logic into a single `tool_call` event hook. This removes redundancy, ensures the agent identity is resolved only once per call, and creates a deterministic pipeline where state-capture (backup) and logging happen in a predictable sequence.

## Architecture Decisions
- **Single Entry Point**: Replace `auto_backup_hook` and `activity_tracing_hook` with a single `intercept_tool_call_hook`.
- **Resolution Order**: Identity Resolution → Activity Log → Conditional Auto-Backup → TUI Notification.
- **Lazy Import Strategy**: Maintain dynamic `import()` calls for `fs` and `save_version` inside the conditional block to avoid loading unnecessary modules for non-modifying tools.
- **Naming Fix**: Use the correct aliased function name (`agent_identity_get_resolved_identity`) to resolve the `get_resolved_identity is not defined` bug, or refactor to a namespace import to avoid aliasing fragility.

## Task List

### Phase 1: Foundation & Analysis
- [ ] **Task 1: Finalize the Unified JS Logic String**
    - **Description**: Combine the logic of `auto_backup_handler_body` and `activity_tracing_handler_body` into a single flow.
    - **Acceptance criteria**:
        - [ ] Identity is resolved once at the top.
        - [ ] Activity log is called for every tool.
        - [ ] Backup logic only triggers for `edit`/`write`.
        - [ ] `ctx.ui.notify` is called for backup success/failure.
        - [ ] Uses the correct aliased function name `agent_identity_get_resolved_identity`.
    - **Verification**: Manual review of the proposed JS string.
    - **Dependencies**: None
    - **Files likely touched**: None (Design only)
    - **Estimated scope**: XS

### Phase 2: Core Implementation
- [ ] **Task 2: Refactor Generator Functions**
    - **Description**: Create `unified_tool_call_handler_body()` in `src/extension_generator.gleam` and remove the two obsolete handler functions.
    - **Acceptance criteria**:
        - [ ] New function produces a single, syntactically correct JS block.
        - [ ] Obsolete functions `auto_backup_handler_body` and `activity_tracing_handler_body` are deleted.
    - **Verification**: `gleam run -m extension_generator` produces a build without errors.
    - **Dependencies**: Task 1
    - **Files likely touched**: `src/extension_generator.gleam`
    - **Estimated scope**: S

- [ ] **Task 3: Register the Unified Hook**
    - **Description**: Update `all_event_hooks()` to return the new consolidated hook.
    - **Acceptance criteria**:
        - [ ] `all_event_hooks()` contains only the unified hook.
        - [ ] `extension.js` output contains exactly one `pi.on('tool_call', ...)` block for the combined logic.
    - **Verification**: `grep "pi.on('tool_call'"` on `extension.js` results in only one match for the interception logic.
    - **Dependencies**: Task 2
    - **Files likely touched**: `src/extension_generator.gleam`
    - **Estimated scope**: XS

### Checkpoint: Functional Integration
- [ ] **Build Verification**: `extension.js` is generated and `psypi` starts without error.
- [ ] **Functional Test**: Execute a non-modifying tool (e.g., `psypi-tasks`) → verify activity log is updated.
- [ ] **State Test**: Execute a modifying tool (e.g., `edit`) → verify activity log AND auto-backup notification appear.

### Phase 3: Polish & Hardening
- [ ] **Task 4: Resolve Naming Debt (The "Weak" Alias)**
    - **Description**: Implement the suggested namespace import or a more robust naming convention to avoid the fragile aliasing that caused the `get_resolved_identity` crash.
    - **Acceptance criteria**:
        - [ ] Generator uses a consistent naming strategy that doesn't break JS strings.
        - [ ] All tools and hooks use the new naming convention.
    - **Verification**: `extension.js` reflects the new naming; all tools continue to function.
    - **Dependencies**: Checkpoint 1
    - **Files likely touched**: `src/extension_generator.gleam`, `src/pi_tool_call.gleam`
    - **Estimated scope**: M

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| **Broken Activity Logging** | High | Test all 17 tools to ensure logs are still generated. |
| **Broken Auto-Backup** | High | Verify `save_version` is called with correct params before any `edit`. |
| **Generator Crash** | Medium | Always run the generator and verify `extension.js` before committing. |

## Open Questions
- None at this stage. The goal is to move from "separate hooks" to "unified pipeline."
