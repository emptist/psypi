# Implementation Plan: Replace Fake Inner AI with Real Pi Agent

**Date**: 2026-05-02  
**Status**: Planning Complete - Ready for Implementation  
**Planner**: S-psypi-psypi  
**Related Research**: `docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md`  
**Priority**: HIGH (Architectural improvement, code simplification)

---

## Executive Summary

This plan outlines the step-by-step implementation to replace the fake inner AI (stateless HTTP API) with a real Pi agent using `createAgentSession()` from Pi SDK. The transformation will convert the current fire-and-forget reviewer into an ever-lasting, context-aware, permanent AI partner.

**Key Benefits**:
- Delete 8+ files of complex fake AI code
- Gain persistent session with conversation history
- Enable proactive monitoring and cross-instance coordination
- Native Pi capabilities (tools, reasoning, context management)

---

## Phase 0: Pre-Implementation (Pre-Requisites)

### Step 0.1: Verify Pi SDK Availability in psypi Context

**Goal**: Ensure `createAgentSession()` can be called from psypi CLI (Node.js context)

**Tasks**:
- [ ] Create test script: `test-pi-sdk.mjs`
- [ ] Test dynamic import of `@mariozechner/pi-coding-agent`
- [ ] Verify session creation works: `const { session } = await createAgentSession(options)`
- [ ] Check if parent session ID needed (psypi runs inside Pi TUI)
- [ ] Document findings

**Test Script** (`test-pi-sdk.mjs`):
```javascript
import { createAgentSession } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession({
  context: { role: 'test', project: 'psypi' }
});

console.log('Session ID:', session.id);
console.log('Session created successfully!');
```

**Success Criteria**:
- [ ] Pi SDK imports successfully
- [ ] `createAgentSession()` works from Node.js context
- [ ] Session ID is UUID v7 format
- [ ] No parent session conflicts

**Estimated Time**: 1 hour

---

### Step 0.2: Database Backup & Migration Prep

**Goal**: Prepare database for permanent partner session tracking

**Tasks**:
- [ ] Backup current `nezha` database
- [ ] Design schema for permanent partner tracking
- [ ] Create migration file: `migrations/XXX_add_permanent_partner.sql`
- [ ] Test migration on backup database
- [ ] Document rollback procedure

**Schema Options**:

**Option A**: New table `permanent_partner`
```sql
CREATE TABLE permanent_partner (
  id SERIAL PRIMARY KEY,
  pi_session_id VARCHAR(255) UNIQUE NOT NULL,
  status VARCHAR(50) DEFAULT 'alive',
  created_at TIMESTAMP DEFAULT NOW(),
  last_heartbeat TIMESTAMP DEFAULT NOW()
);
```

**Option B**: Reuse `agent_sessions` table
```sql
ALTER TABLE agent_sessions ADD COLUMN is_permanent BOOLEAN DEFAULT FALSE;
CREATE INDEX idx_agent_sessions_permanent ON agent_sessions(is_permanent) WHERE is_permanent = TRUE;
```

**Recommendation**: Option A (cleaner separation)

**Success Criteria**:
- [ ] Database backed up
- [ ] Migration file created and tested
- [ ] Rollback procedure documented

**Estimated Time**: 2 hours

---

## Phase 1: Core Implementation (PermanentPartnerService)

### Step 1.1: Create PermanentPartnerService

**File**: `src/kernel/services/PermanentPartnerService.ts`

**Purpose**: Wrap `createAgentSession()` and manage the permanent partner lifecycle

**Interface**:
```typescript
export interface PermanentPartnerService {
  // Get or create the permanent partner session
  getOrCreateSession(): Promise<PiSession>;
  
  // Execute a task using the permanent partner
  executeTask(prompt: string, timeoutMs?: number): Promise<TaskResult>;
  
  // Run reflection using the permanent partner
  runReflection(prompt: string): Promise<ReflectionResult>;
  
  // Heartbeat (keep session alive)
  heartbeat(): Promise<void>;
  
  // Terminate session (when last psypi instance ends)
  terminate(): Promise<void>;
}
```

**Implementation Sketch**:
```typescript
import { createAgentSession } from "@mariozechner/pi-coding-agent";
import { DatabaseClient } from '../db/DatabaseClient.js';

export class PermanentPartnerService {
  private db: DatabaseClient;
  private session: any = null; // Pi session object
  private sessionId: string | null = null;
  
  constructor(db: DatabaseClient) {
    this.db = db;
  }
  
  async getOrCreateSession() {
    // Check DB for existing alive session
    const existing = await this.db.query(
      `SELECT pi_session_id FROM permanent_partner WHERE status = 'alive' LIMIT 1`
    );
    
    if (existing.rows[0]) {
      this.sessionId = existing.rows[0].pi_session_id;
      // Reconnect to existing Pi session (implementation TBD)
      return this.session;
    }
    
    // Create new Pi agent session
    const { session } = await createAgentSession({
      context: { 
        role: 'permanent-partner', 
        project: 'psypi',
        identityId: 'P-tencent/hy3-preview:free-psypi'
      }
    });
    
    this.session = session;
    this.sessionId = session.id;
    
    // Store in DB
    await this.db.query(
      `INSERT INTO permanent_partner (pi_session_id, status) VALUES ($1, 'alive')`,
      [this.sessionId]
    );
    
    return session;
  }
  
  async executeTask(prompt: string, timeoutMs = 300000): Promise<TaskResult> {
    const session = await this.getOrCreateSession();
    
    const startTime = Date.now();
    try {
      // Use Pi session to execute task
      const result = await session.complete(prompt); // Method name TBD
      
      return {
        success: true,
        message: result.content,
        output: result.content,
        durationMs: Date.now() - startTime
      };
    } catch (error) {
      return {
        success: false,
        message: error.message,
        output: error.message,
        durationMs: Date.now() - startTime
      };
    }
  }
  
  async heartbeat() {
    await this.db.query(
      `UPDATE permanent_partner SET last_heartbeat = NOW() WHERE pi_session_id = $1`,
      [this.sessionId]
    );
  }
  
  async terminate() {
    if (this.sessionId) {
      await this.db.query(
        `UPDATE permanent_partner SET status = 'dead' WHERE pi_session_id = $1`,
        [this.sessionId]
      );
      // Optionally: call session.terminate() if available
    }
  }
}
```

**Success Criteria**:
- [ ] `PermanentPartnerService` created
- [ ] `getOrCreateSession()` works
- [ ] Session persisted in database
- [ ] Unit tests written

**Estimated Time**: 4 hours

---

### Step 1.2: Update InterReviewService to Use PermanentPartnerService

**File**: `src/kernel/services/InterReviewService.ts`

**Changes**:
- Remove `AIProviderFactory.createInnerProvider()`
- Inject `PermanentPartnerService` instead of `AIProvider`
- Update `complete()` calls to use Pi session

**Before**:
```typescript
static async create(db, getSessionId) {
  const aiProvider = await AIProviderFactory.createInnerProvider(db);
  return new InterReviewService(db, aiProvider, getSessionId);
}
```

**After**:
```typescript
static async create(db, getSessionId) {
  const partnerService = await PermanentPartnerService.create(db);
  return new InterReviewService(db, partnerService, getSessionId);
}
```

**Success Criteria**:
- [ ] InterReviewService uses `PermanentPartnerService`
- [ ] Code reviews still work (test with `psypi commit`)
- [ ] Review quality improved (has context from previous reviews)

**Estimated Time**: 3 hours

---

### Step 1.3: Update CLI Commands

**File**: `src/cli.ts`

**Changes**:
Update `inner` command to use `PermanentPartnerService`:

```typescript
.innerCommand
  .command('model')
  .action(async () => {
    const db = DatabaseClient.getInstance();
    const partner = await PermanentPartnerService.create(db);
    const session = await partner.getOrCreateSession();
    console.log('Permanent Partner Session ID:', session.id);
  });
```

**Success Criteria**:
- [ ] `psypi inner model` shows Pi session ID (UUID v7)
- [ ] `psypi inner review` works with new service
- [ ] All `inner` subcommands functional

**Estimated Time**: 2 hours

---

## Phase 2: Lifecycle Management & Advanced Features

### Step 2.1: Implement Session Lifecycle Coupling

**Goal**: Tie permanent partner session to psypi instance lifecycle

**Tasks**:
- [ ] Hook into psypi startup: call `getOrCreateSession()`
- [ ] Hook into psypi shutdown: check if last instance, then `terminate()`
- [ ] Implement heartbeat mechanism (keepalive every 5 minutes)
- [ ] Handle orphaned sessions (cleanup on startup)

**Implementation**:
```typescript
// In psypi startup (src/cli.ts or extension)
const partner = await PermanentPartnerService.create(db);
await partner.getOrCreateSession();

// Register shutdown handler
process.on('SIGINT', async () => {
  const aliveCount = await db.query(
    `SELECT COUNT(*) FROM agent_sessions WHERE agent_type = 'psypi' AND status = 'alive'`
  );
  if (aliveCount.rows[0].count === 0) {
    await partner.terminate();
  }
  process.exit(0);
});
```

**Success Criteria**:
- [ ] Session created on psypi startup
- [ ] Session terminated when last psypi instance ends
- [ ] Heartbeat keeps session alive during long operations

**Estimated Time**: 3 hours

---

### Step 2.2: Add Proactive Monitoring Capabilities

**Goal**: Enable permanent partner to perform background tasks

**Tasks**:
- [ ] Implement background loop (check every 10 minutes)
- [ ] Monitor stalled tasks (no update in 24 hours)
- [ ] Detect duplicate work across instances
- [ ] Generate project health reports
- [ ] Auto-triage new issues (assign priority/severity)

**Implementation** (in `PermanentPartnerService`):
```typescript
startBackgroundLoop() {
  setInterval(async () => {
    await this.checkStalledTasks();
    await this.detectDuplicateWork();
    await this.generateHealthReport();
  }, 10 * 60 * 1000); // 10 minutes
}
```

**Success Criteria**:
- [ ] Background loop runs without blocking main thread
- [ ] Stalled tasks detected and reported
- [ ] Health reports generated periodically

**Estimated Time**: 4 hours

---

## Phase 3: Cleanup & Simplification

### Step 3.1: Delete Fake AI Code

**Files to Delete**:
- [ ] `src/kernel/services/ai/AIProvider.ts`
- [ ] `src/kernel/services/ai/AIProviderFactory.ts`
- [ ] `src/kernel/services/ai/OpenRouterProvider.ts`
- [ ] `src/kernel/services/ai/OpenAIProvider.ts`
- [ ] `src/kernel/services/ai/AnthropicProvider.ts`
- [ ] `src/kernel/services/ai/OllamaProvider.ts`
- [ ] `src/kernel/services/ai/GLM5Provider.ts`
- [ ] `src/kernel/services/InnerAgentExecutor.ts`

**Verification**:
- [ ] Build succeeds after deletion (`pnpm build`)
- [ ] No import errors
- [ ] All references updated

**Estimated Time**: 2 hours

---

### Step 3.2: Simplify/Remove ApiKeyService (for inner AI)

**File**: `src/kernel/services/ApiKeyService.ts`

**Changes**:
- [ ] Remove `getCurrentInnerProvider()` method (no longer needed)
- [ ] Keep other methods (for external API keys)
- [ ] Update tests

**Success Criteria**:
- [ ] `ApiKeyService` simplified
- [ ] No references to inner provider in code
- [ ] External API key functionality preserved

**Estimated Time**: 1 hour

---

### Step 3.3: Update Documentation

**Files to Update**:
- [ ] `README.md` - Remove "fake inner AI" warnings, update architecture diagram
- [ ] `AGENTS.md` - Document new permanent partner system
- [ ] `docs/vision-permanent-ai-partner.md` - Mark as IMPLEMENTED
- [ ] `COMMANDS.md` - Update `inner` command documentation
- [ ] Create `docs/ARCHITECTURE-permanent-partner.md`

**Success Criteria**:
- [ ] All docs reflect new architecture
- [ ] Migration guide created (old → new)
- [ ] Benefits documented

**Estimated Time**: 2 hours

---

## Phase 4: Testing & Validation

### Step 4.1: Integration Testing

**Test Scenarios**:
- [ ] **Test 1**: Start psypi, verify permanent partner session created
- [ ] **Test 2**: Run `psypi commit`, verify inter-review uses Pi agent
- [ ] **Test 3**: Start multiple psypi instances, verify shared session
- [ ] **Test 4**: Stop all psypi instances, verify session terminated
- [ ] **Test 5**: Restart psypi, verify session reconnected (if alive)
- [ ] **Test 6**: Check conversation history persists between calls

**Test Script**: `test-permanent-partner.sh`
```bash
#!/bin/bash
# Test 1: Start psypi and check session
echo "Test 1: Start psypi"
psypi my-session-id
psypi partner-id

# Test 2: Run inter-review
echo "Test 2: Inter-review"
psypi commit "test: verify permanent partner review"

# Add more tests...
```

**Success Criteria**:
- [ ] All test scenarios pass
- [ ] No regressions in existing functionality
- [ ] Performance acceptable (< 2x slowdown)

**Estimated Time**: 4 hours

---

### Step 4.2: Performance Testing

**Metrics to Measure**:
- [ ] Inter-review time (before vs after)
- [ ] Session creation time
- [ ] Memory usage (before vs after)
- [ ] Database query count (before vs after)

**Benchmark Script**: `bench-permanent-partner.sh`

**Success Criteria**:
- [ ] Performance degradation < 2x
- [ ] Memory usage stable
- [ ] No database query spikes

**Estimated Time**: 2 hours

---

## Phase 5: Rollout & Monitoring

### Step 5.1: Phased Rollout

**Phase 5a**: Parallel Implementation (Optional)
- Keep old `AIProvider` code working alongside new `PermanentPartnerService`
- Feature flag to switch between old and new
- Test in production with low-risk tasks

**Phase 5b**: Full Switch
- Remove feature flag
- Delete old code (Phase 3)
- Monitor for issues

**Success Criteria**:
- [ ] Smooth transition (no downtime)
- [ ] No user-facing errors
- [ ] Issues caught early

**Estimated Time**: 2 days (monitoring period)

---

### Step 5.2: Post-Implementation Monitoring

**Metrics to Track**:
- [ ] Inter-review success rate
- [ ] Inter-review quality score (average)
- [ ] Permanent partner session uptime
- [ ] Error rate (session creation failures, etc.)
- [ ] User satisfaction (feedback)

**Monitoring Script**: `monitor-permanent-partner.sh`
- Query database for session status
- Check error logs
- Generate daily report

**Success Criteria**:
- [ ] Success rate > 95%
- [ ] Quality score improvement (from 70/100 to 85+/100)
- [ ] No critical errors

**Estimated Time**: Ongoing

---

## Summary: Estimated Total Time

| Phase | Description | Time Estimate |
|-------|-------------|---------------|
| Phase 0 | Pre-Implementation | 3 hours |
| Phase 1 | Core Implementation | 9 hours |
| Phase 2 | Lifecycle & Advanced Features | 7 hours |
| Phase 3 | Cleanup & Simplification | 5 hours |
| Phase 4 | Testing & Validation | 6 hours |
| Phase 5 | Rollout & Monitoring | 2 days (monitoring) |
| **TOTAL** | | **30 hours (core) + 2 days monitoring** |

---

## Risks & Mitigation (Reminder)

| Risk | Mitigation |
|------|------------|
| Pi SDK not available in psypi context | Phase 0.1 verification before proceeding |
| Session lifecycle complexity | Robust heartbeat and cleanup (Phase 2.1) |
| Breaking existing functionality | Phase 5a parallel implementation |
| Performance overhead | Phase 4.2 performance testing |
| Database migration issues | Phase 0.2 backup and rollback prep |

---

## Success Criteria (Final Checklist)

### Functional:
- [ ] Permanent partner is a **real Pi agent** (UUID v7 session ID)
- [ ] Session **persists** across psypi instances
- [ ] **Conversation history** maintained between calls
- [ ] **Inter-review works** with new Pi agent
- [ ] **Proactive monitoring** possible (background tasks)
- [ ] **Cross-instance awareness** (knows about other psypi instances)

### Non-Functional:
- [ ] **No regression** in existing functionality
- [ ] **Performance** acceptable (< 2x slowdown)
- [ ] **Code simplification** (deleted 8+ files)
- [ ] **Proper error handling** (session creation failures, etc.)
- [ ] **Documentation updated** (README, AGENTS.md, etc.)

---

## Next Steps After Planning

1. ✅ **Research complete** (`docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md`)
2. ✅ **Planning complete** (this document)
3. ⏳ **Create database migration** (Phase 0.2)
4. ⏳ **Verify Pi SDK** (Phase 0.1)
5. ⏳ **Implement Phase 1** (Core implementation)
6. ⏳ **Test & rollout**

---

**Plan Status**: ✅ COMPLETE - Ready for Implementation  
**Dependencies**: Database migration, Pi SDK verification  
**Priority**: HIGH  
**Estimated Start Date**: After database migration complete
