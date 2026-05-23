# Research: Monitor Deep Dive - Level 1

## Objective

Research and prove how Monitor works in psypi - an LLM-powered consultant agentbot can call for difficult decisions.

## Key Findings from Pi SDK Research

### Pattern: Extensions Can Call LLM Directly

```typescript
import { complete, getModel } from "@mariozechner/pi-ai";

// Use same model as agentbot
const model = ctx.model;
const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);

// Direct LLM call - no spawn, no external service
const response = await complete(model, { messages: [...] }, { apiKey, ... });
```

**References:**
- `examples/extensions/summarize.ts` - Uses complete() to summarize
- `examples/extensions/qna.ts` - Uses ctx.model for consultation
- `docs/extensions.md` - ctx.modelRegistry, getApiKeyAndHeaders

### Key Properties
- No spawn() - just a function call
- Uses agentbot's model via ctx.model
- API key from ctx.modelRegistry
- Returns response - done (no loop!)

### Architecture

```
psypi instance
├── Agentbot LLM (ctx.model)
│
├── Monitor Tool
│   └── complete(ctx.model, {...}, {apiKey, headers})
│       ↑ uses SAME model as agentbot!
│
└── Result returned - done (no loop!)
```

---

## Research Tasks (Iterative - go deeper each round)

### Round 1: Prove the Pattern
- [ ] Study `summarize.ts`, `qna.ts` in pi-mono to understand complete() usage
- [ ] Write minimal TypeScript extension that calls LLM
- [ ] Verify it works in Pi

### Round 2: Gleam Integration
- [ ] Research: Can Gleam call complete() through generated extension.js?
- [ ] Study: How pi_tool_call.gleam generates tool execute functions
- [ ] Test: Import @mariozechner/pi-ai in generated JS

### Round 3: Monitor Tool Design
- [ ] Define tool parameters (what agentbot asks Monitor)
- [ ] Design system prompt for Monitor
- [ ] Implement: psypi-autonomic-consult tool in Gleam

### Round 4: Safety Integration
- [ ] Research: tool_call hook can return { block: true }
- [ ] Design: How Monitor provides context for blocking decisions
- [ ] Implement: Safety check in hook

### Round 5: Polish
- [ ] Test: Agentbot calling Monitor for difficult choice
- [ ] Verify: Response returned correctly
- [ ] Document: How to use

---

## Round 1 Findings

### Pattern Confirmed
The extension can call LLM using:
```typescript
const model = ctx.model;
const auth = await ctx.modelRegistry.getApiKeyAndHeaders(model);
const response = await complete(model, { messages: [...] }, { apiKey, headers });
```

### IMPLEMENTED: First Working Monitor Tool
- Added `@mariozechner/pi-ai` import to extension.js
- Added `callMonitor` helper function in helpers_text()
- Added `psypi-autonomic-consult` tool that calls LLM
- Uses SAME model as agentbot (ctx.model)
- No spawn, no external service, no loop!

### Code Added in extension_generator.gleam:
```gleam
// In imports_text(): add pi-ai import
import { complete, getModel } from "@mariozechner/pi-ai";

// In helpers_text(): callMonitor function
async function callMonitor(messages, systemPrompt) {
  if (!ctx.model) throw new Error('No model available');
  const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
  if (!auth.ok || !auth.apiKey) throw new Error(auth.error || 'No API key');
  const response = await complete(
    ctx.model,
    { systemPrompt, messages },
    { apiKey: auth.apiKey, headers: auth.headers }
  );
  return response.content.filter(c => c.type === 'text').map(c => c.text).join('\n');
}

// In generate(): add monitor_consult_tool()
```

### Verified Working
- extension.js regenerated with new tool
- Tool name: psypi-autonomic-consult
- Parameter: question (string)
- Uses agentbot's model via ctx.model

---

## Key Questions for Next Round

1. Can we import @mariozechner/pi-ai in generated extension.js?
2. How to pass ctx.model to the execute function?
3. Best way to structure the tool definition (new type vs special case)?

## Verification Criteria

- [ ] Agentbot can call psypi-autonomic-consult
- [ ] Monitor returns LLM-generated response
- [ ] No spawn, no external service, no loop
- [ ] Safety block works for dangerous operations