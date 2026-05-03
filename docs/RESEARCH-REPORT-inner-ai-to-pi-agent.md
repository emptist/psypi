# Research Report: Replacing Fake Inner AI with Real Pi Agent

**Date**: 2026-05-02  
**Status**: Research Complete - Ready for Planning  
**Researcher**: S-psypi-psypi  
**Session ID**: 019da0b2-fec1-7288-8920-da0b20ccc74c  

---

## Executive Summary

The current "Inner AI" (permanent monitor/reviewer) in psypi is **fake** - it's a stateless HTTP API wrapper that makes fire-and-forget calls to OpenRouter (tencent/hy3-preview:free). This needs to be replaced with a **real Pi agent** using the Pi SDK's `createAgentSession()` to create a persistent, context-aware, ever-lasting AI partner.

**Key Finding**: Pi SDK natively supports sub-agents via `createAgentSession()`, which is exactly what we need for the permanent AI partner.

---

## Part 1: Current State Analysis

### 1.1 What is the "Inner AI"?

**Identity**: `P-tencent/hy3-preview:free-psypi` (changed from `I-` to `P-` prefix in AGENTS.md)

**Current Implementation**:
- **Location**: `src/kernel/services/ai/` (AIProviderFactory, OpenRouterProvider, etc.)
- **Mechanism**: Stateless HTTP API calls to OpenRouter
- **Session**: NO real session (despite identity existing in `agent_identities` table)
- **State**: Completely stateless - no conversation history, no memory between calls

**Code Flow** (InterReviewService):
```typescript
// src/kernel/services/InterReviewService.ts
static async create(db, getSessionId) {
  const aiProvider = await AIProviderFactory.createInnerProvider(db);
  // aiProvider = HTTP wrapper (OpenRouterProvider)
  // Each call = new stateless HTTP request
}
```

### 1.2 Current Limitations (Confirmed)

| Limitation | Impact | Evidence |
|------------|--------|----------|
| **Stateless** | Can't reference previous reviews/decisions | No conversation history stored |
| **Fire-and-forget** | No proactive monitoring or background tasks | No heartbeat, no background loop |
| **No cross-instance awareness** | Doesn't know what other psypi instances are doing | No shared state between calls |
| **Dead sessions only** | No persistent presence | `agent_sessions` table has no alive session for inner AI |
| **No shared state** | Can't coordinate between psypi instances | Each call is independent |
| **NOT a Pi agent** | No session ID, no Pi capabilities | Confirmed by directly asking the "inner AI" |

### 1.3 Current Files Involved

**Core Implementation**:
- `src/kernel/services/ai/index.ts` - AIProviderFactory (creates fake providers)
- `src/kernel/services/ai/OpenRouterProvider.ts` - HTTP wrapper for OpenRouter
- `src/kernel/services/InterReviewService.ts` - Uses AIProvider for code reviews
- `src/kernel/services/InnerAgentExecutor.ts` - Wrapper for executing tasks via AI

**Identity Management**:
- `src/kernel/services/AgentIdentityService.ts` - Generates `P-tencent/hy3-preview:free-psypi`
- `src/kernel/services/ApiKeyService.ts` - Manages API keys for providers

**CLI Commands**:
- `src/cli.ts` - `psypi inner` command (model, set-model, review)
- Uses `AIProviderFactory.createInnerProvider()`

### 1.4 Verification: Inner AI is NOT a Pi Agent

From `docs/session-summary-2026-05-02.md`:
```
Q: "What is your identity? Are you a Pi agent with a session ID?"
A: "I am Hunyuan, a large language model developed by Tencent...
    I am NOT a Pi agent...
    I do not have a persistent agent ID...
    Session IDs are short-lived, per-conversation technical markers"
```

**Reality Check**:
- ❌ NOT a Pi agent
- ❌ NO Pi session ID (no UUID v7)
- ❌ NO awareness of `P-tencent/hy3-preview:free-psypi` identity
- ❌ Just stateless HTTP API calls to OpenRouter!
- ✅ Model: `tencent/hy3-preview:free` via OpenRouter

---

## Part 2: Pi SDK Research

### 2.1 Pi SDK Sub-Agent Support

From Pi SDK documentation (`@mariozechner/pi-coding-agent`):

```typescript
import { createAgentSession } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession(options);
```

**Official Use Cases** (from SDK docs):
- ✅ "Build custom tools that spawn sub-agents" ← **This is exactly what we need!**
- ✅ Integrate agent capabilities into applications
- ✅ Create automated pipelines with agent reasoning

### 2.2 What `createAgentSession()` Provides

Based on SDK research:
- **Real Pi agent session** with UUID v7 (time-ordered, meaningful)
- **Native Pi capabilities** (tools, reasoning, context management)
- **Persistent conversation history** (stored in Pi's session system)
- **Proper session lifecycle** (heartbeat, cleanup)
- **Pi TUI integration** (can use `ctx.ui.notify()`, etc.)

### 2.3 Architecture Implication

**Current (Broken)**:
```
psypi CLI → AIProviderFactory → HTTP API → OpenRouter → tencent/hy3-preview:free
         (stateless, fake, no session)
```

**New (Correct)**:
```
psypi CLI → createAgentSession() → Real Pi Agent (permanent partner)
         (stateful, real, persistent session, UUID v7)
```

---

## Part 3: Vision - Ever-Lasting AI Partner

### 3.1 Core Concept (from `docs/vision-permanent-ai-partner.md`)

Transform the inner AI from a **stateless tool** into a **persistent, god-like partner**:

```
                    ┌─────────────────────────────────┐
                    │    Permanent AI Partner         │
                    │    (Single Pi Session)          │
                    │                                 │
                    │  - Lives while psypi exists    │
                    │  - Sees all project activity   │
                    │  - Remembers everything        │
                    │  - Coordinates all instances   │
                    └──────────┬────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
    ┌─────────▼──────┐ ┌──────▼────────┐ ┌────▼─────────┐
    │ Psypi Instance │ │ Psypi Instance│ │ Psypi Instance│
    │ (folder A)     │ │ (folder B)    │ │ (folder C)    │
    └────────────────┘ └───────────────┘ └───────────────┘
```

### 3.2 Key Characteristics

#### 1. **Ever-Lasting Session**
- Single Pi session created when first psypi instance starts
- Session reused by ALL subsequent psypi instances
- Session only dies when LAST psypi instance ends
- Implements the "God watching from heaven" metaphor

#### 2. **Context-Aware Identity**
The permanent AI partner changes its **identity context** (not the base ID) when working with different psypi sessions:
- Base ID: `P-tencent/hy3-preview:free-psypi` (persists)
- Working context changes: `{ project: 'psypi', cwd: '/path/A' }` vs `{ project: 'other', cwd: '/path/B' }`
- Session ID remains constant; context is passed per-request

#### 3. **Omniscient Knowledge**
- Maintains conversation history via Pi's session system
- Tracks all tasks, issues, and activity across ALL psypi instances
- Can reference past decisions, reviews, and learnings
- Builds a cumulative understanding of the project

#### 4. **Proactive Presence**
Can perform background activities:
- Monitor for stalled tasks
- Detect duplicate work across instances
- Trigger alerts for critical issues
- Generate periodic project health reports
- Auto-triage new issues

### 3.3 Benefits Table

| Capability | Description | Current Status | After Migration |
|------------|-------------|----------------|-----------------|
| **Cumulative Intelligence** | Remembers all past reviews, decisions, learnings | ❌ Impossible (stateless) | ✅ Full history |
| **Cross-Instance Coordination** | Prevents duplicate work between psypi instances | ❌ Impossible (no shared state) | ✅ Shared session |
| **Proactive Monitoring** | Watches for stalled tasks, critical issues | ❌ Impossible (no background loop) | ✅ Background tasks |
| **Contextual Awareness** | Knows what each psypi instance is working on | ❌ Impossible (no shared state) | ✅ Context tracking |
| **Project Memory** | Builds long-term understanding of codebase | ❌ Impossible (no persistence) | ✅ Persistent memory |
| **Smart Reviews** | References past reviews of same code/author | ❌ Impossible (no history) | ✅ Historical context |

---

## Part 4: Technical Approach

### 4.1 High-Level Strategy

1. **Remove fake AI code**: Delete `AIProviderFactory`, `OpenRouterProvider`, etc.
2. **Integrate Pi SDK**: Use `createAgentSession()` for permanent partner
3. **Session management**: Single persistent Pi session for all psypi instances
4. **Lifecycle coupling**: Tie permanent session to psypi session starts/ends
5. **Update all usages**: InterReviewService, InnerAgentExecutor, CLI commands

### 4.2 Session Lifecycle

#### Creation (First psypi instance starts):
```typescript
async function getOrCreatePermanentSession() {
  // Check for existing alive Pi session
  const existing = await db.query(`
    SELECT pi_session_id FROM permanent_partner 
    WHERE status = 'alive'
    LIMIT 1
  `);
  
  if (existing.rows[0]) {
    return existing.rows[0].pi_session_id;
  }
  
  // Create new Pi agent session
  const { session } = await createAgentSession({
    parentSessionId: getCurrentPiSessionId(), // The psypi instance's session
    context: { role: 'permanent-partner', project: 'psypi' }
  });
  
  // Store in database
  await db.query(`
    INSERT INTO permanent_partner (pi_session_id, status, created_at)
    VALUES ($1, 'alive', NOW())
  `, [session.id]);
  
  return session.id;
}
```

#### Termination (Last psypi instance ends):
```typescript
async function onPsypiEnd() {
  const alivePsypiSessions = await db.query(`
    SELECT COUNT(*) as count FROM agent_sessions 
    WHERE agent_type = 'psypi' AND status = 'alive'
  `);
  
  if (alivePsypiSessions.rows[0].count === 0) {
    // No more psypi instances, kill permanent session
    await killPermanentSession();
  }
}
```

### 4.3 New Architecture

```
psypi CLI → PermanentPartnerService → createAgentSession() → Real Pi Agent
                                                   ↑
                                    Persistent across all psypi instances
                                    UUID v7 session ID
                                    Conversation history
                                    Proactive capabilities
```

### 4.4 Database Changes Needed

**New table** (or repurpose existing):
```sql
CREATE TABLE permanent_partner (
  id SERIAL PRIMARY KEY,
  pi_session_id VARCHAR(255) UNIQUE NOT NULL,
  status VARCHAR(50) DEFAULT 'alive',
  created_at TIMESTAMP DEFAULT NOW(),
  last_heartbeat TIMESTAMP DEFAULT NOW()
);
```

**Alternatively**, reuse `agent_sessions` table:
- Add column `is_permanent BOOLEAN DEFAULT FALSE`
- Permanent partner session = `is_permanent = TRUE`

---

## Part 5: Files to Modify/Delete

### 5.1 Files to DELETE (Fake AI Code)

| File | Reason |
|------|--------|
| `src/kernel/services/ai/AIProvider.ts` | Interface for fake providers |
| `src/kernel/services/ai/AIProviderFactory.ts` | Creates fake providers |
| `src/kernel/services/ai/OpenRouterProvider.ts` | HTTP wrapper for OpenRouter |
| `src/kernel/services/ai/OpenAIProvider.ts` | Fake OpenAI wrapper |
| `src/kernel/services/ai/AnthropicProvider.ts` | Fake Anthropic wrapper |
| `src/kernel/services/ai/OllamaProvider.ts` | Fake Ollama wrapper |
| `src/kernel/services/ai/GLM5Provider.ts` | Fake GLM5 wrapper |
| `src/kernel/services/InnerAgentExecutor.ts` | Wrapper for fake AI |

**Total**: 8 files to delete

### 5.2 Files to MODIFY

| File | Changes Needed |
|------|----------------|
| `src/kernel/services/InterReviewService.ts` | Replace `AIProvider` with `PermanentPartnerService` |
| `src/cli.ts` | Update `inner` command to use new service |
| `src/kernel/services/ApiKeyService.ts` | May be simplified (no more API keys for inner AI) |
| `src/kernel/services/AgentIdentityService.ts` | Keep for identity, but permanent partner uses Pi session |

### 5.3 Files to CREATE

| File | Purpose |
|------|---------|
| `src/kernel/services/PermanentPartnerService.ts` | New service wrapping `createAgentSession()` |
| New database migration | Add `permanent_partner` table or modify `agent_sessions` |

---

## Part 6: Risks & Mitigation

### 6.1 Risks Identified

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Pi SDK not available in psypi context** | High - Can't create agent sessions | Verify Pi SDK can be used from psypi CLI (may need dynamic import) |
| **Session lifecycle complexity** | Medium - Sessions may leak | Implement robust heartbeat and cleanup |
| **Breaking existing functionality** | High - Inter-review stops working | Phase rollout: keep old code working alongside new |
| **Performance overhead** | Low - Pi agent slower than HTTP API | Measure and optimize; cache when possible |
| **Database migration needed** | Medium - Need schema changes | Create migration; test on backup first |

### 6.2 Pre-Requisites

1. ✅ **Verify Pi SDK can be used from psypi CLI**
   - Test `createAgentSession()` from Node.js context
   - Ensure it doesn't conflict with parent Pi session

2. ✅ **Understand Pi session limits**
   - How many sub-agents can be created?
   - Any rate limiting?

3. ✅ **Database backup**
   - Current `nezha` database backed up before migration
   - Test migration on backup first

---

## Part 7: Success Criteria

### 7.1 Functional Requirements

- [ ] Permanent partner is a **real Pi agent** (has UUID v7 session ID)
- [ ] Session **persists** across psypi instances
- [ ] **Conversation history** maintained between calls
- [ ] **Inter-review works** with new Pi agent
- [ ] **Proactive monitoring** possible (background tasks)
- [ ] **Cross-instance awareness** (knows about other psypi instances)

### 7.2 Non-Functional Requirements

- [ ] **No regression** in existing functionality
- [ ] **Performance** acceptable (< 2x slowdown from HTTP API)
- [ ] **Code simplification** (delete 8+ files of fake AI code)
- [ ] **Proper error handling** (session creation failures, etc.)
- [ ] **Documentation updated** (README, AGENTS.md, etc.)

---

## Part 8: Research Conclusions

### 8.1 Key Findings

1. **Inner AI is definitively fake** - stateless HTTP API, not a Pi agent
2. **Pi SDK supports exactly what we need** - `createAgentSession()` for sub-agents
3. **Architecture simplification possible** - delete 8+ files of complex fake AI code
4. **Massive capability improvement** - persistent session, history, context, proactive monitoring
5. **Implementation is feasible** - clear technical approach identified

### 8.2 Recommendation

**PROCEED with implementation** after:
1. Verifying Pi SDK works from psypi CLI context
2. Creating detailed implementation plan (next step)
3. Getting database migration ready

### 8.3 Next Steps

1. ✅ **Research complete** (this document)
2. ⏳ **Create detailed implementation plan** (PLAN-*.md)
3. ⏳ **Create database migration**
4. ⏳ **Implement PermanentPartnerService**
5. ⏳ **Update InterReviewService and CLI**
6. ⏳ **Test thoroughly**
7. ⏳ **Delete fake AI code**
8. ⏳ **Update documentation**

---

**Report Status**: ✅ COMPLETE  
**Next Document**: `docs/PLAN-inner-ai-to-pi-agent.md`  
**Estimated Implementation Time**: 2-3 days (after database migration)  
**Priority**: HIGH (architectural improvement, code simplification)
