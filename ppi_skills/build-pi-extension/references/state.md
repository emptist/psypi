# Pi Extension State Management

## Pattern 1: In-Memory + Session Reconstruction

Best for: stateful tools that need to survive `/reload` and session restarts.

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function (pi: ExtensionAPI) {
  let items: string[] = [];

  // Reconstruct state from session history
  pi.on("session_start", async (_event, ctx) => {
    items = [];
    for (const entry of ctx.sessionManager.getBranch()) {
      if (entry.type === "message" && entry.message.role === "toolResult") {
        if (entry.message.toolName === "my_list") {
          items = entry.message.details?.items ?? [];
        }
      }
    }
  });

  pi.registerTool({
    name: "my_list",
    label: "My List",
    description: "Add or list items",
    parameters: Type.Object({
      action: Type.StringEnum(["list", "add"] as const),
      text: Type.Optional(Type.String()),
    }),
    async execute(_id, params) {
      if (params.action === "add" && params.text) {
        items.push(params.text);
      }
      return {
        content: [{ type: "text", text: items.join("\n") || "(empty)" }],
        details: { items: [...items] }, // Store for reconstruction
      };
    },
  });
}
```

## Pattern 2: Session Entry Persistence

Best for: state that should NOT appear in LLM context but must survive restarts.

```typescript
// Save state (not in LLM context)
pi.appendEntry("my-state", { count: 42, lastRun: Date.now() });

// Restore on session start
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getEntries()) {
    if (entry.type === "custom" && entry.customType === "my-state") {
      // Reconstruct from entry.data
    }
  }
});
```

## Pattern 3: Custom Message Injection

Best for: sending context to the LLM (appears in conversation).

```typescript
// Steer: inject during current turn (after tool calls, before next LLM call)
pi.sendMessage({
  customType: "my-status",
  content: "Background task completed",
  display: true,
}, { deliverAs: "steer", triggerTurn: true });

// FollowUp: wait for agent to finish, then deliver
pi.sendMessage({
  customType: "my-status",
  content: "Follow-up message",
  display: true,
}, { deliverAs: "followUp" });

// NextTurn: queue for next user prompt
pi.sendMessage({
  customType: "my-status",
  content: "Queued for next turn",
  display: true,
}, { deliverAs: "nextTurn" });
```

## Pattern 4: Session Metadata

```typescript
// Set session name (shown in session selector)
pi.setSessionName("Refactor auth module");

// Label entries for navigation
pi.setLabel(entryId, "checkpoint-before-refactor");
pi.setLabel(entryId, undefined); // Clear
```

## Pattern 5: Inter-Extension Communication

```typescript
// Extension A emits
pi.events.on("data:ready", (data) => {
  console.log("Data ready:", data);
});

// Extension B listens
pi.events.emit("data:ready", { items: [1, 2, 3] });
```

## Pattern 6: Session Replacement

```typescript
pi.registerCommand("handoff", {
  handler: async (_args, ctx) => {
    const kickoff = "Continue from the replacement session";
    await ctx.newSession({
      withSession: async (newCtx) => {
        // Use newCtx, NOT the old ctx
        await newCtx.sendUserMessage(kickoff);
      },
    });
  },
});
```

**⚠️ Don't use old `pi` or old `ctx` inside `withSession` — they're stale.**

## Choosing a Pattern

| Need | Pattern |
|---|---|
| Tool state that survives restarts | Pattern 1 (details + reconstruction) |
| Hidden state (not in LLM context) | Pattern 2 (appendEntry) |
| Send context to LLM mid-session | Pattern 3 (sendMessage) |
| Bookmark / name things | Pattern 4 (setSessionName / setLabel) |
| Cross-extension communication | Pattern 5 (pi.events) |
| Spawn replacement sessions | Pattern 6 (newSession / fork) |
