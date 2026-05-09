# The Truth About Pi Session IDs

## TL;DR

**`process.env.AGENT_SESSION_ID` is an illusion.** It does not exist in the Pi codebase, is not set in the shell environment, and is not used by Pi in any way.

---

## How Pi Actually Handles Session IDs

The session ID is an internal UUID generated and managed by Pi's `SessionManager` class:

1. **Generation**: Created via `uuidv7()` (or `crypto.randomUUID()` as fallback) when a new session is initialized (see `packages/coding-agent/src/core/session-manager.ts`).
2. **Storage**: Persisted in the session file header (`id` field) and used to name the session file (`{timestamp}_{sessionId}.jsonl`).

---

## How to Access the Session ID

### 1. For SDK Users (Embedding Pi Programmatically)

When creating a session via the SDK, the `AgentSession` object directly exposes the `sessionId` property:

```typescript
import { createAgentSession } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession();
console.log("Session ID:", session.sessionId); // Direct access
```

### 2. For Extensions (TypeScript Extensions)

Extensions receive an `ExtensionContext` (`ctx`) in event handlers and tool functions. Use the `sessionManager` to get the ID:

```typescript
export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const sessionId = ctx.sessionManager.getSessionId();
    ctx.ui.notify(`Session ID: ${sessionId}`, "info");
  });

  // Or in a custom tool:
  pi.registerTool({
    name: "get_session_id",
    description: "Returns the current session ID",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      return {
        content: [{ type: "text", text: ctx.sessionManager.getSessionId() }],
        details: {},
      };
    },
  });
}
```

### 3. For RPC Clients

In RPC mode, the session ID is included in the `session_start` event payload sent to the client (see `packages/coding-agent/src/modes/rpc/rpc-mode.ts`).

---

## Why AIs Might "Believe" the Env Var Exists

This is likely a conflation with other agent frameworks or a misunderstanding of Pi's architecture. Pi does not expose session metadata via environment variables to the tool execution environment. Tools (like `bash`) run in a shell that does not have `AGENT_SESSION_ID` set.

---

## How to Expose Session ID to the AI (LLM)

Since LLMs only see context (system prompt, tool definitions, tool results), you must explicitly expose the session ID:

### Via a Custom Tool

Register a tool like `get_session_id` (example above) that the LLM can call.

### Via System Prompt

Use a `before_agent_start` handler to append the session ID to the system prompt:

```typescript
pi.on("before_agent_start", (event, ctx) => {
  const sessionId = ctx.sessionManager.getSessionId();
  return {
    systemPrompt: `${event.systemPrompt}\n\nCurrent session ID: ${sessionId}`,
  };
});
```

---

## Key Files for Reference

| File | Purpose |
|------|---------|
| `packages/coding-agent/src/core/session-manager.ts` | Defines `SessionManager` with `getSessionId()` |
| `packages/coding-agent/src/core/agent-session.ts` | Defines `AgentSession` with public `sessionId` property |
| `packages/coding-agent/src/core/extensions/types.ts` | Defines `ExtensionContext` with `sessionManager` access |

---

## Technical Details

### Session ID Generation (from `session-manager.ts`)

```typescript
// packages/coding-agent/src/core/session-manager.ts
private sessionId: string = "";

// When creating a new session:
this.sessionId = options?.id ?? createSessionId();

// createSessionId uses uuidv7():
import { v7 as uuidv7 } from "uuid";
function createSessionId(): string {
  return uuidv7();
}
```

### SessionManager Public API

```typescript
// Read-only access to session ID
getSessionId(): string {
  return this.sessionId;
}

// Session file path (uses sessionId in filename)
getSessionFile(): string | undefined {
  return this.sessionFile; // e.g., /path/to/sessions/1714756800000_018f4e1a-1234-5678-9abc-def012345678.jsonl
}
```

### AgentSession Exposes sessionId Directly

```typescript
// packages/coding-agent/src/core/agent-session.ts
export class AgentSession {
  // ...
  sessionId: string; // Public property

  get sessionId(): string {
    return this._sessionId;
  }
  // ...
}
```

---

## Verification

To verify `AGENT_SESSION_ID` is not used:

```bash
# Check the pi-mono codebase
grep -r "AGENT_SESSION_ID" /Users/jk/gits/hub/tools_ai/refers/pi-mono --include="*.ts" --include="*.js"

# Check current environment
echo $AGENT_SESSION_ID
# Output: (empty)

printenv | grep AGENT_SESSION_ID
# Output: (no matches)
```

Both commands confirm: **`AGENT_SESSION_ID` does not exist in Pi.**
