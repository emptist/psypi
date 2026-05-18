# Monitor Feedback Improvement Plan

## 🚩 Current State Analysis
The current Monitor feedback system is perceived as **incomplete**, **annoying**, and **architecturally flawed**.

### Key Issues:
1. **High Noise-to-Signal Ratio**: Frequent `console.log` entries for lifecycle events (session start, agent start/end) that provide no actionable value.
2. **Perceived Instability**: The repeated display of "started" messages suggests the Monitor is being re-initialized improperly, rather than existing as a permanent session guardian.
3. **Static Status**: The `psypi-monitor` status label is a static "Monitor ready", providing no real-time information about system health.
4. **Abrasive Blocking**: Safety blocks are reported as `[Monitor] BLOCKED: ...`, which feels like a system error rather than helpful guidance.
5. **Technical Leakage**: Logging internal reasons (e.g., `event.reason`) is useful for developers but confusing for end-users.

## 🎯 The "Silent Guardian" Philosophy
The Monitor should move from a "Chatty Assistant" to a "Silent Guardian." 

### Communication Hierarchy:
- **Sillent Mode (Default)**: Background operations (heartbeats, lifecycle events) should be invisible to the human user.
- **Agentbot-to-Agentbot (Internal)**: The Monitor communicates with the Agentbot AI (via system prompts/context injection) to guide the process without bothering the user.
- **Emergency Channel (Human-Facing)**: The Monitor only speaks to the user when:
    - **System is in Danger**: (e.g., Infinite loop, recursive delete, critical crash).
    - **Explicit Request**: The user calls a monitor tool (e.g., `psypi-autonomic-health`).

## 🛠️ Architectural Pivot: From Hooks to Service
The "repeated started" messages reveal that the Monitor is currently implemented as a collection of reactive JS hooks rather than a persistent service.

### Proposed Shift:
1. **State-Based Monitoring**: Move away from "trigger-based logging" toward a singleton state in `extension.js` that only notifies the UI when a state change occurs (e.g., Healthy $\to$ Critical).
2. **Backend Brain**: Move safety logic (regexes) and decision-making from JS strings in the generator to the Gleam core. The extension should be a thin bridge that asks the Gleam backend if an action is safe.
3. **Management by Exception**: The Monitor should only interrupt the user when it is managing an exception.

## 🚀 Implementation Roadmap
1. **Cull the Noise**: Remove all non-essential lifecycle logs (`Session started`, `Agent started`, etc.) from `extension_generator.gleam`.
2. **Refactor Safety Messages**: Replace "BLOCKED" with helpful, guidance-based language.
3. **Dynamic Status**: Replace "Monitor ready" with a dynamic signal tied to actual system health metrics.
4. **Context Injection**: Implement the logic to inject critical issues/memories directly into the agent's prompt, making the Monitor's value felt through the Agentbot's improved behavior rather than through logs.
