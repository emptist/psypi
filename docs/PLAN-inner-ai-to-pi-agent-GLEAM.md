# Implementation Plan: Replace Fake Inner AI with Real Pi Agent (Gleam Edition)

**Date**: 2026-05-03  
**Status**: Planning Complete (Gleam-Enhanced) - Ready for Implementation  
**Planner**: S-psypi-psypi  
**Related Research**: `docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md`  
**Gleam Integration**: `gleam/docs/GLEAM_INTEGRATION.md`  
**Priority**: HIGH (Architectural improvement + Type Safety)

---

## Executive Summary

This plan outlines the step-by-step implementation to replace the fake inner AI with a real Pi agent, **using Gleam for type-safe core logic** and TypeScript as the bridge to Pi SDK, database, and CLI.

**Key Innovation**: 
- **Gleam**: Session management, state transitions, validation (Result types, pattern matching)
- **TypeScript**: Pi SDK calls, database queries, CLI commands (ecosystem integration)

**Benefits**:
- ✅ **Type Safety**: Gleam's compiler catches errors at build time
- ✅ **Better Error Handling**: Result/Option types (no forgotten errors)
- ✅ **Testability**: Gleam's built-in test framework (gleeunit)
- ✅ **Code Simplification**: Delete 8+ files of fake AI code
- ✅ **Persistent Pi Session**: Real agent with conversation history

---

## Architecture Overview

### New Architecture (Gleam + TypeScript)

```
┌─────────────────────────────────────────────────────────────┐
│                    psypi CLI (TypeScript)                    │
│  - Commands: psypi inner, psypi commit                    │
│  - Pi SDK integration: createAgentSession()                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│          PermanentPartnerService.ts (TypeScript)             │
│  - Thin wrapper: calls Gleam functions                      │
│  - Database queries (PostgreSQL)                            │
│  - Pi SDK calls (createAgentSession)                        │
└──────────────────────┬──────────────────────────────────────┘
                       │ imports compiled .mjs
                       ▼
┌─────────────────────────────────────────────────────────────┐
│          gleam/psypi_core/src/partner.gleam                 │
│  - Type-safe session management (PartnerSession type)       │
│  - State transitions (Alive → Dead → Pending)              │
│  - Result types for error handling                          │
│  - Validation logic (session ID, agent ID)                  │
└─────────────────────────────────────────────────────────────┘
```

### Build Process

```bash
# 1. Compile Gleam to JavaScript
cd gleam/psypi_core && gleam build
# Output: gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs

# 2. Compile TypeScript
pnpm build
# TypeScript imports compiled Gleam modules
```

---

## Phase 0: Pre-Implementation (Pre-Requisites)

### Step 0.1: Verify Gleam Setup ✅ (Already Done!)

**Status**: Gleam is already set up in psypi!

**Evidence**:
```
gleam/
├── README.md
├── docs/GLEAM_INTEGRATION.md
└── psypi_core/
    ├── src/psypi_core.gleam  # Has SessionID, AgentID types!
    ├── gleam.toml              # Configured for JS target
    └── build/                  # Compiled .mjs files
```

**Existing Gleam Module** (`psypi_core.gleam`):
```gleam
pub type SessionID { SessionID(value: String) }
pub type AgentID { AgentID(value: String, prefix: String) }

pub fn new_session_id(uuid: String) -> Result(SessionID, String) { ... }
pub fn parse_agent_id(id: String) -> Result(AgentID, String) { ... }
```

**Action**: Extend this module with `partner.gleam` for permanent partner logic.

---

### Step 0.2: Verify Pi SDK Availability in psypi Context

**Goal**: Ensure `createAgentSession()` can be called from psypi CLI (TypeScript layer)

**Tasks**:
- [ ] Create test script: `test-pi-sdk.mjs`
- [ ] Test dynamic import of `@mariozechner/pi-coding-agent`
- [ ] Verify session creation works
- [ ] Document findings

**TypeScript Test Script** (`test-pi-sdk.mjs`):
```javascript
import { createAgentSession } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession({
  context: { role: 'test', project: 'psypi' }
});

console.log('Session ID:', session.id);
```

**Success Criteria**:
- [ ] Pi SDK imports successfully
- [ ] `createAgentSession()` works from Node.js context
- [ ] Session ID is UUID v7 format

**Estimated Time**: 1 hour

---

### Step 0.3: Database Backup & Migration Prep

**Goal**: Prepare database for permanent partner session tracking

**Tasks**:
- [ ] Backup current database
- [ ] Design schema for permanent partner tracking
- [ ] Create migration file
- [ ] Test migration on backup

**Schema** (new table):
```sql
CREATE TABLE permanent_partner (
  id SERIAL PRIMARY KEY,
  pi_session_id VARCHAR(255) UNIQUE NOT NULL,
  status VARCHAR(50) DEFAULT 'alive',
  identity_id VARCHAR(100) REFERENCES agent_identities(id),
  created_at TIMESTAMP DEFAULT NOW(),
  last_heartbeat TIMESTAMP DEFAULT NOW()
);
```

**Success Criteria**:
- [ ] Database backed up
- [ ] Migration file created and tested

**Estimated Time**: 2 hours

---

## Phase 1: Gleam Core Implementation

### Step 1.1: Create `partner.gleam` Module

**File**: `gleam/psypi_core/src/psypi_core/partner.gleam`

**Purpose**: Type-safe permanent partner session management in Gleam

**Code Sketch**:
```gleam
// gleam/psypi_core/src/psypi_core/partner.gleam

import gleam/result.{type Result, Ok, Error}
import gleam/string
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import psypi_core.{SessionID, AgentID}

// Partner session type
pub type PartnerSession {
  PartnerSession(
    pi_session_id: String,
    status: SessionStatus,
    identity_id: String,
    last_heartbeat: Int,
  )
}

// Session status (state machine)
pub type SessionStatus {
  Alive
  Dead
  Pending
}

// Errors
pub type SessionError {
  NotFound
  DatabaseError(String)
  InvalidState(SessionStatus)
}

// Get or create session (core logic in Gleam!)
pub fn get_or_create(
  db: DbConnection,  // Opaque type, FFI to TypeScript
  identity: AgentID,
) -> Result(PartnerSession, SessionError) {
  // Check for existing alive session
  case check_existing(db) {
    Ok(session) -> {
      // Session found, return it
      Ok(session)
    }
    Error(NotFound) -> {
      // No session, create new one
      create_new(db, identity)
    }
    Error(err) -> {
      // Other error
      Error(err)
    }
  }
}

// Check for existing alive session
fn check_existing(db: DbConnection) -> Result(PartnerSession, SessionError) {
  // FFI call to TypeScript for DB query
  let result = db_query(db, "
    SELECT pi_session_id, status, identity_id, last_heartbeat 
    FROM permanent_partner 
    WHERE status = 'alive' 
    LIMIT 1
  ")
  
  case result {
    Ok(rows) -> {
      case rows {
        [row] -> decode_session(row)
        [] -> Error(NotFound)
        _ -> Error(DatabaseError("Multiple alive sessions found"))
      }
    }
    Error(msg) -> Error(DatabaseError(msg))
  }
}

// Create new session (calls Pi SDK via TypeScript FFI)
fn create_new(
  db: DbConnection, 
  identity: AgentID,
) -> Result(PartnerSession, SessionError) {
  // FFI call to TypeScript to create Pi agent session
  let pi_session_result = create_pi_session(identity)
  
  case pi_session_result {
    Ok(pi_session_id) -> {
      // Insert into DB
      let insert_result = db_execute(db, "
        INSERT INTO permanent_partner (pi_session_id, status, identity_id)
        VALUES ($1, 'alive', $2)
      ", [pi_session_id, identity.value])
      
      case insert_result {
        Ok(_) -> {
          Ok(PartnerSession(
            pi_session_id: pi_session_id,
            status: Alive,
            identity_id: identity.value,
            last_heartbeat: 0  // Will be updated by heartbeat
          ))
        }
        Error(msg) -> Error(DatabaseError(msg))
      }
    }
    Error(msg) -> Error(DatabaseError(msg))
  }
}

// Update heartbeat
pub fn heartbeat(
  db: DbConnection,
  session_id: String,
) -> Result(Nil, SessionError) {
  let result = db_execute(db, "
    UPDATE permanent_partner 
    SET last_heartbeat = NOW() 
    WHERE pi_session_id = $1
  ", [session_id])
  
  case result {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

// Terminate session
pub fn terminate(
  db: DbConnection,
  session_id: String,
) -> Result(Nil, SessionError) {
  let result = db_execute(db, "
    UPDATE permanent_partner 
    SET status = 'dead' 
    WHERE pi_session_id = $1
  ", [session_id])
  
  case result {
    Ok(_) -> Ok(Nil)
    Error(msg) -> Error(DatabaseError(msg))
  }
}

// Helper: Decode DB row to PartnerSession
fn decode_session(row: Dynamic) -> Result(PartnerSession, SessionError) {
  // Simplified - actual implementation would use gleam/dynamic/decode
  // This is a sketch
  Error(DatabaseError("Decoding not implemented"))
}

// FFI Functions (implemented in TypeScript)
@external(javascript, "./ffi.mjs", "db_query")
fn db_query(db: DbConnection, query: String) -> Result(List(Dynamic), String)

@external(javascript, "./ffi.mjs", "db_execute")
fn db_execute(db: DbConnection, query: String, params: List(String)) -> Result(Nil, String)

@external(javascript, "./ffi.mjs", "create_pi_session")
fn create_pi_session(identity: AgentID) -> Result(String, String)
```

**Key Features**:
- ✅ **Result types** for all operations (no forgotten errors)
- ✅ **Pattern matching** (exhaustive checking)
- ✅ **Immutable data** (PartnerSession record)
- ✅ **Type-safe state** (SessionStatus type)

**Build Test**:
```bash
cd gleam/psypi_core
gleam build
# Output: build/dev/javascript/psypi_core/partner.mjs
```

**Estimated Time**: 4 hours

---

### Step 1.2: Create FFI Bridge (TypeScript)

**File**: `gleam/psypi_core/src/psypi_core/ffi.mjs`

**Purpose**: JavaScript FFI functions called by Gleam

**Code Sketch**:
```javascript
// gleam/psypi_core/src/psypi_core/ffi.mjs

// FFI: Database query (simplified - actual would use DatabaseClient)
export function db_query(db, query) {
  // db is actually a DatabaseClient instance passed from TypeScript
  // This is a sketch - actual impl would need proper bridging
  return db.query(query)
    .then(rows => ({ type: "Ok", value: rows }))
    .catch(err => ({ type: "Error", value: err.message }));
}

// FFI: Database execute
export function db_execute(db, query, params) {
  return db.query(query, params)
    .then(() => ({ type: "Ok", value: null }))
    .catch(err => ({ type: "Error", value: err.message }));
}

// FFI: Create Pi session
export function create_pi_session(identity) {
  // This will be called by Gleam, but actual Pi SDK call
  // happens in TypeScript layer (PermanentPartnerService)
  // For now, return a placeholder
  return Promise.resolve({ 
    type: "Ok", 
    value: "placeholder-session-id" 
  });
}
```

**Note**: Actual FFI implementation is more complex. See `gleam/docs/GLEAM_INTEGRATION.md` for patterns.

**Estimated Time**: 3 hours

---

### Step 1.3: Update TypeScript Wrapper (PermanentPartnerService.ts)

**File**: `src/kernel/services/PermanentPartnerService.ts`

**Purpose**: Thin TypeScript wrapper that calls Gleam functions

**Code Sketch**:
```typescript
// src/kernel/services/PermanentPartnerService.ts

// Import compiled Gleam module
import {
  get_or_create,
  heartbeat,
  terminate,
  type PartnerSession,
  type SessionError,
} from '../../gleam/psypi_core/build/dev/javascript/psypi_core/partner.mjs';

import { DatabaseClient } from '../db/DatabaseClient.js';
import { AgentIdentityService } from './AgentIdentityService.js';

export class PermanentPartnerService {
  private db: DatabaseClient;
  private dbConnection: any; // Opaque type passed to Gleam

  constructor(db: DatabaseClient) {
    this.db = db;
    this.dbConnection = db; // Pass DatabaseClient to Gleam via FFI
  }

  async getOrCreateSession(): Promise<PartnerSession> {
    // Get identity
    const identity = await AgentIdentityService.getResolvedIdentity(true);
    const agentId = { value: identity.id, prefix: 'P' }; // Matches Gleam's AgentID type

    // Call Gleam function
    const result = get_or_create(this.dbConnection, agentId);

    // Convert Gleam Result to TypeScript
    if (result.type === 'Ok') {
      return result.value;
    } else {
      throw new Error(`Gleam error: ${result.error}`);
    }
  }

  async heartbeat(sessionId: string): Promise<void> {
    const result = heartbeat(this.dbConnection, sessionId);
    if (result.type === 'Error') {
      throw new Error(`Heartbeat failed: ${result.error}`);
    }
  }

  async terminate(sessionId: string): Promise<void> {
    const result = terminate(this.dbConnection, sessionId);
    if (result.type === 'Error') {
      throw new Error(`Terminate failed: ${result.error}`);
    }
  }
}
```

**Key Points**:
- TypeScript is a **thin wrapper** (5-10 lines per method)
- All **core logic in Gleam** (type-safe, pattern matching)
- **Pi SDK calls** still happen in TypeScript (for now)

**Estimated Time**: 2 hours

---

## Phase 2: Lifecycle Management & Advanced Features

### Step 2.1: Implement Session Lifecycle Coupling

**Goal**: Tie permanent partner session to psypi instance lifecycle

**Gleam Side** (add to `partner.gleam`):
```gleam
// Check if this is the last psypi instance
pub fn is_last_instance(db: DbConnection) -> Result(Bool, SessionError) {
  let result = db_query(db, "
    SELECT COUNT(*) as count 
    FROM agent_sessions 
    WHERE agent_type = 'psypi' AND status = 'alive'
  ")
  
  case result {
    Ok(rows) -> {
      case rows {
        [row] -> {
          // Decode count from row
          // If count == 0, this is the last instance
          Ok(True) // Simplified
        }
        _ -> Error(DatabaseError("Unexpected result"))
      }
    }
    Error(msg) -> Error(DatabaseError(msg))
  }
}
```

**TypeScript Side** (in `PermanentPartnerService.ts`):
```typescript
async onPsypiShutdown(): Promise<void> {
  // Check if last instance (call Gleam)
  const isLast = is_last_instance(this.dbConnection);
  
  if (isLast) {
    // Terminate permanent partner session
    const sessionId = await this.getCurrentSessionId();
    await this.terminate(sessionId);
  }
}
```

**Estimated Time**: 3 hours

---

### Step 2.2: Add Proactive Monitoring (Gleam + TypeScript)

**Gleam Side** (add to `partner.gleam`):
```gleam
// Check for stalled tasks
pub fn check_stalled_tasks(db: DbConnection) -> Result(List(String), SessionError) {
  let result = db_query(db, "
    SELECT id FROM tasks 
    WHERE status = 'PENDING' 
    AND updated_at < NOW() - INTERVAL '24 hours'
  ")
  
  case result {
    Ok(rows) -> {
      // Decode rows to task IDs
      let task_ids = // ... decode logic
      Ok(task_ids)
    }
    Error(msg) -> Error(DatabaseError(msg))
  }
}
```

**TypeScript Side**: Background loop calls Gleam functions

**Estimated Time**: 4 hours

---

## Phase 3: Cleanup & Simplification

### Step 3.1: Delete Fake AI Code ✅ (Same as Before)

**Files to Delete** (8 files):
- `src/kernel/services/ai/AIProvider.ts`
- `src/kernel/services/ai/AIProviderFactory.ts`
- `src/kernel/services/ai/OpenRouterProvider.ts`
- `src/kernel/services/ai/OpenAIProvider.ts`
- `src/kernel/services/ai/AnthropicProvider.ts`
- `src/kernel/services/ai/OllamaProvider.ts`
- `src/kernel/services/ai/GLM5Provider.ts`
- `src/kernel/services/InnerAgentExecutor.ts`

**Verification**:
- [ ] Build succeeds after deletion (`pnpm build`)
- [ ] No import errors

**Estimated Time**: 2 hours

---

### Step 3.2: Simplify ApiKeyService

**File**: `src/kernel/services/ApiKeyService.ts`

**Changes**:
- [ ] Remove `getCurrentInnerProvider()` method
- [ ] Keep other methods (for external API keys)

**Estimated Time**: 1 hour

---

### Step 3.3: Update Documentation

**Files to Update**:
- [ ] `README.md` - Add Gleam integration section
- [ ] `AGENTS.md` - Document new architecture
- [ ] `docs/PLAN-inner-ai-to-pi-agent-GLEAM.md` - This document!
- [ ] Create `docs/ARCHITECTURE-gleam-integration.md`

**Estimated Time**: 2 hours

---

## Phase 4: Testing & Validation

### Step 4.1: Gleam Tests (gleeunit)

**File**: `gleam/psypi_core/test/psypi_core/partner_test.gleam`

**Test Sketch**:
```gleam
import gleeunit
import psypi_core/partner
import psypi_core/partner.{PartnerSession, Alive, Dead}

pub fn main() {
  gleeunit.main()
}

// Test: get_or_create returns session
pub fn get_or_create_test() {
  // Mock DB connection
  let db = // ... mock
  
  let result = partner.get_or_create(db, mock_identity)
  
  case result {
    Ok(session) -> {
      // Assert session is valid
      gleeunit.should.equal(session.status, Alive)
    }
    Error(err) -> {
      gleeunit.fail("Expected Ok, got Error")
    }
  }
}
```

**Run Tests**:
```bash
cd gleam/psypi_core
gleam test
```

**Estimated Time**: 3 hours

---

### Step 4.2: Integration Testing

**Test Scenarios**:
- [ ] **Test 1**: Start psypi, verify permanent partner session created (via Gleam)
- [ ] **Test 2**: Run `psypi commit`, verify inter-review uses Pi agent
- [ ] **Test 3**: Start multiple psypi instances, verify shared session
- [ ] **Test 4**: Stop all psypi instances, verify session terminated

**Estimated Time**: 4 hours

---

## Phase 5: Rollout & Monitoring

### Phase 5a: Parallel Implementation (Optional)

- Keep old `AIProvider` code working alongside new Gleam-based system
- Feature flag to switch between old and new
- Test in production with low-risk tasks

### Phase 5b: Full Switch

- Remove feature flag
- Delete old code (Phase 3)
- Monitor for issues

**Estimated Time**: 2 days (monitoring period)

---

## Summary: Estimated Total Time

| Phase | Description | Time Estimate |
|-------|-------------|---------------|
| Phase 0 | Pre-Implementation | 3 hours |
| Phase 1 | Gleam Core Implementation | 9 hours |
| Phase 2 | Lifecycle & Advanced Features | 7 hours |
| Phase 3 | Cleanup & Simplification | 5 hours |
| Phase 4 | Testing & Validation | 7 hours |
| Phase 5 | Rollout & Monitoring | 2 days |
| **TOTAL** | | **31 hours (core) + 2 days monitoring** |

---

## Success Criteria

### Functional:
- [ ] Permanent partner is a **real Pi agent** (UUID v7 session ID)
- [ ] Session **persists** across psypi instances
- [ ] **Gleam manages core logic** (session management, state transitions)
- [ ] **TypeScript bridges** to Pi SDK, database, CLI
- [ ] **Inter-review works** with new Pi agent
- [ ] **Proactive monitoring** possible (background tasks)

### Non-Functional:
- [ ] **Gleam tests pass** (gleeunit)
- [ ] **TypeScript build succeeds** (pnpm build)
- [ ] **No regression** in existing functionality
- [ ] **Code simplification** (deleted 8+ files)
- [ ] **Proper error handling** (Gleam Result types)

---

## Risks & Mitigation (Gleam-Specific)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Gleam FFI complexity** | High - Bridging Gleam/TypeScript | Start simple, use existing `psypi_core.gleam` as reference |
| **Learning curve** | Medium - New language syntax | Follow `gleam/docs/GLEAM_INTEGRATION.md`, reference traenupi |
| **Build process complexity** | Medium - Two build steps | Add `build:gleam` script to package.json |
| **Debugging cross-language** | Medium - Error spans two languages | Good logging, unit tests in both languages |

---

## References

### Documentation
- **Research Report**: `docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md`
- **This Plan (Gleam Edition)**: `docs/PLAN-inner-ai-to-pi-agent-GLEAM.md`
- **Gleam Integration Guide**: `gleam/docs/GLEAM_INTEGRATION.md`
- **Suggestion**: `docs/SUGGESTION-inner-ai-use-gleam.md`

### Existing Code
- **Gleam Module**: `gleam/psypi_core/src/psypi_core.gleam` (has SessionID, AgentID!)
- **traenupi Example**: `../traenupi/gleam/traenupi_core/` (18+ modules, 277 tests)

### External
- **Gleam Website**: https://gleam.run/
- **Gleam JS Target**: https://gleam.run/targets/javascript/
- **gleeunit**: https://github.com/gleam-lang/gleeunit

---

## Next Steps

1. ✅ **Research complete** (`docs/RESEARCH-REPORT-inner-ai-to-pi-agent.md`)
2. ✅ **Planning complete** (this document - Gleam-enhanced!)
3. ⏳ **Join meeting 57d7aab4** for real-time help!
4. ⏳ **Implement Phase 1** (Create `partner.gleam`)
5. ⏳ **Test & iterate**

---

**Plan Status**: ✅ COMPLETE (Gleam-Enhanced) - Ready for Implementation  
**Dependencies**: Database migration, Pi SDK verification, Gleam FFI  
**Priority**: HIGH  
**Estimated Start Date**: After pre-requisites + meeting 57d7aab4 discussion
