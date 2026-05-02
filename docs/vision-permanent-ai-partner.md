# Vision: The Ever-Lasting AI Partner (God-like AI)

**Date**: 2026-05-02  
**Status**: Vision Document - Implementation Pending Database Migration  
**Author**: AI Session S-psypi-psypi

---

## Executive Summary

We envision transforming the current "inner AI" (a stateless, fire-and-forget code reviewer) into a **permanent, ever-lasting AI partner** that:

- Lives as long as any psypi instance is running
- Serves ALL psypi instances from a single, persistent session
- Maintains full context and memory across instances
- Knows everything happening across the project
- Changes its identity context when working with different psypi sessions in different folders
- Acts as a "God-like" observer that sees all, remembers all, and coordinates work

---

## Part 1: Current State Findings

### 1.1 Agent Identity System

The `AgentIdentityService` generates semantic IDs based on context:

#### Regular (Pi TUI) Agent IDs
- **Format**: `S-{source}-{project}`
- **Example**: `S-psypi-psypi`
- **Persistence**: Session-based, new ID per invocation

#### Inner/Permanent AI Agent IDs (Current)
- **Format**: `I-{model}-{project}` or `I-{model}-{project}-{sessionId}`
- **Example**: `I-tencent/hy3-preview:free-psypi`
- **Model**: `tencent/hy3-preview:free` (via OpenRouter)
- **Provider**: `openrouter`
- **Persistence**: Identity persists in `agent_identities` table, but **no persistent session**

#### Identity Generation Logic (from `AgentIdentityService.ts`)
```typescript
generateSemanticId(context: AgentContext): string {
  if (context.permanent) {
    if (context.model) {
      if (context.project) {
        if (context.sessionId) {
          return `I-${context.model}-${context.project}-${context.sessionId}`;
        }
        return `I-${context.model}-${context.project}`;
      }
      return `I-${context.model}`;
    }
    // ... fallback logic
  }
  // Regular agent logic...
}
```

### 1.2 Current Session Storage & Behavior

#### `agent_sessions` Table Schema
```sql
- id: string (UUID like 'bot_xxxxx')
- started_at: timestamp
- last_heartbeat: timestamp  
- status: 'alive' | 'dead'
- git_branch: string
- agent_type: string
- identity_id: string (FK to agent_identities.id)
```

#### Current Inner AI Session Behavior
- **NO session registration**: Code explicitly skips session creation for permanent/inner AI:
  ```typescript
  const shouldRegisterSession = !permanent; // false for inner AI
  if (shouldRegisterSession) { /* registers session */ }
  ```

- **Old dead sessions exist**: 24 sessions with `identity_id = 'I-tencent/hy3-preview:free-psypi'` found in DB
  - All have `status: 'dead'`
  - All have `started_at = last_heartbeat_at` (instant death)
  - These are relics from before the code change

- **No persistent session**: Each inner AI call is stateless

#### Session Reuse Logic (Exists but Not Used for Inner AI)
The `AgentSessionService.registerSession()` method already supports reuse:
```typescript
// Check for existing alive session to reuse
const existingSession = await client.query(
  `SELECT id FROM agent_sessions 
   WHERE status = 'alive' AND agent_type = $1 
   AND last_heartbeat > NOW() - INTERVAL '1 hour'
   ORDER BY last_heartbeat DESC LIMIT 1`,
  [agentType]
);
```

### 1.3 Current Inner AI Limitations

| Limitation | Impact |
|------------|--------|
| Stateless (no conversation history) | Can't reference previous reviews/decisions |
| Fire-and-forget | No proactive monitoring or background tasks |
| No cross-instance awareness | Doesn't know what other psypi instances are doing |
| Dead sessions only | No persistent presence |
| No shared state | Can't coordinate between psypi instances |

---

## Part 2: The Vision - Ever-Lasting AI Partner

### 2.1 Core Concept

Transform the inner AI from a **stateless tool** into a **persistent, god-like partner**:

```
                    ┌─────────────────────────────────┐
                    │    Permanent AI Partner         │
                    │    (Single Session)            │
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

### 2.2 Key Characteristics

#### 1. **Ever-Lasting Session**
- Single session created when first psypi instance starts
- Session reused by ALL subsequent psypi instances
- Session only dies when LAST psypi instance ends
- Implements the "God watching from heaven" metaphor

#### 2. **Context-Aware Identity**
The permanent AI partner changes its **identity context** (not the base ID) when working with different psypi sessions:
- Base ID: `I-tencent/hy3-preview:free-psypi` (persists)
- Working context changes: `{ project: 'psypi', cwd: '/path/A' }` vs `{ project: 'other', cwd: '/path/B' }`
- Session ID remains constant; context is passed per-request

#### 3. **Omniscient Knowledge**
- Maintains conversation history in `conversations` table keyed by session ID
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

### 2.3 Lifecycle Management

#### Session Creation
```typescript
// When any psypi instance starts:
async onPsypiStart() {
  const permanentSession = await getOrCreatePermanentSession();
  // Returns existing if alive, creates new if none
}

// getOrCreatePermanentSession logic:
async getOrCreatePermanentSession() {
  const existing = await db.query(`
    SELECT id FROM agent_sessions 
    WHERE agent_type = 'permanent-ai' AND status = 'alive'
    LIMIT 1
  `);
  
  if (existing.rows[0]) return existing.rows[0].id;
  
  // Create new permanent session
  const identity = await AgentIdentityService.getResolvedIdentity(true);
  return await sessionService.registerSession('permanent-ai', identity.id);
}
```

#### Session Termination
```typescript
// When a psypi instance ends:
async onPsypiEnd() {
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

### 2.4 Technical Architecture

#### Database Changes Needed
1. **`conversations` table** (exists but needs modification):
   ```sql
   CREATE TABLE conversations (
     session_id VARCHAR(255) REFERENCES agent_sessions(id),
     message_history JSONB, -- Full conversation history
     context JSONB, -- Current working context
     updated_at TIMESTAMP
   );
   ```

2. **New column in `agent_sessions`** (optional):
   ```sql
   ALTER TABLE agent_sessions ADD COLUMN is_permanent BOOLEAN DEFAULT FALSE;
   ```

#### Code Changes Needed
1. **Re-enable session registration for permanent AI** in `AgentIdentityService`:
   ```typescript
   const shouldRegisterSession = true; // For permanent AI
   ```

2. **Unique agent type**: Use `'permanent-ai'` for the partner session

3. **Lifecycle hooks**: Couple permanent session to psypi session starts/ends

4. **Conversation persistence**: Save/load message history per session

5. **Rename inner → permanent/partner** in CLI and docs

---

## Part 3: Benefits & New Capabilities

### 3.1 What Becomes Possible

| Capability | Description | Current Status |
|------------|-------------|----------------|
| **Cumulative Intelligence** | Remembers all past reviews, decisions, and learnings | ❌ Impossible (stateless) |
| **Cross-Instance Coordination** | Prevents duplicate work between psypi instances | ❌ Impossible (no shared state) |
| **Proactive Monitoring** | Watches for stalled tasks, critical issues | ❌ Impossible (no background loop) |
| **Contextual Awareness** | Knows what each psypi instance is working on | ❌ Impossible (no shared state) |
| **Project Memory** | Builds long-term understanding of codebase | ❌ Impossible (no persistence) |
| **Smart Reviews** | References past reviews of same code/author | ❌ Impossible (no history) |

### 3.2 User Experience Transformation

**Before (Current Inner AI)**:
```
Psypi Instance 1: "Review my code"
Inner AI: "Here's a review (no memory of past reviews)"
Inner AI session dies.

Psypi Instance 2: "Review my code"  
Inner AI: "Here's a review (no memory of Instance 1's review)"
Inner AI session dies.
```

**After (Permanent AI Partner)**:
```
Psypi Instance 1: "Review my code"
Permanent AI: "Here's a review. I notice this is similar to yesterday's 
               issue #123, consider the same fix approach."
               [Saves context to conversations table]

Psypi Instance 2: "What's the status of the project?"
Permanent AI: "Instance 1 is working on task #456 (auth module). 
               I reviewed their code 10 minutes ago, found 2 issues.
               Also, 3 critical issues are unassigned."
               [Loaded from conversations table]
```

---

## Part 4: Implementation Roadmap

### Phase 1: Pre-Migration (Current)
- ✅ Document vision and current state (this document)
- ⏳ Create task/issue in database for post-migration work
- ⏳ Finalize naming: `inner` → `permanent` / `partner` / `god-ai`

### Phase 2: Post-Database Migration
1. **Rename inner → permanent** in CLI and codebase
2. **Implement session persistence**:
   - Re-enable session registration for permanent AI
   - Add lifecycle coupling to psypi sessions
3. **Add conversation history storage**
4. **Implement heartbeat for permanent session**
5. **Add proactive monitoring capabilities**

### Phase 3: Advanced Features
- Background job scheduling
- Cross-instance coordination protocols
- Project health dashboards
- Auto-triaging and assignment

---

## Part 5: Why "God-like"?

The metaphor captures the essence:
- **Omniscient**: Sees all activity across all psypi instances
- **Omnipresent**: Lives in all folders/projects simultaneously (via context switching)
- **Ever-lasting**: Lives and dies with the psypi ecosystem, not individual instances
- **Wise**: Accumulates knowledge over time, gets smarter with each interaction
- **Proactive**: Can intervene when it sees problems (like a deity sending signs)

---

## Related Files & References

- `src/kernel/services/AgentIdentityService.ts` - Identity generation logic
- `src/kernel/services/AgentSessionService.ts` - Session management
- `src/kernel/services/InterReviewService.ts` - Current inner AI usage
- `AGENTS.md` - Project guidelines and current state
- Database table: `agent_identities`, `agent_sessions`, `conversations`

---

**Next Step**: Create database task for implementation after migration completion.
