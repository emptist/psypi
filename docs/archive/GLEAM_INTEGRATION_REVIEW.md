# Deep Dive Review: psypi's Gleam Integration

**Review Date**: 2026-05-03  
**Reviewer**: Trae AI (TraeNuPI)  
**Depth Level**: Full Codebase Analysis

---

## Executive Summary

| Category | Score | Reality Check |
|----------|-------|---------------|
| **Documentation** | ⭐⭐⭐⭐⭐ | Excellent plans, no execution |
| **Gleam Code** | ⭐⭐☆☆☆ | 2 modules, placeholder implementations |
| **TypeScript Integration** | ⭐☆☆☆☆ | **ZERO imports** - not connected |
| **FFI Implementation** | ⭐⭐⭐☆☆ | Has real Pi SDK, but orphaned |
| **Testing** | ⭐☆☆☆☆ | 1 placeholder test |

**Critical Finding**: The psypi project has **excellent documentation** and a **working FFI file with real Pi SDK integration**, but **Gleam is NOT actually integrated into the TypeScript codebase**. The `partner_ffi.mjs` file has a working `create_pi_session()` function that calls `@mariozechner/pi-coding-agent`, but it's never imported anywhere.

---

## 1. Architecture Analysis

### Current State (What Exists)

```
psypi/
├── gleam/                                    # Gleam layer (PLANNED)
│   └── psypi_core/
│       ├── src/
│       │   ├── psypi_core.gleam             # ✅ Basic types (SessionID, AgentID)
│       │   └── psypi_core/
│       │       ├── partner.gleam            # ⚠️ Placeholder implementations
│       │       └── partner_ffi.mjs          # ✅ Has REAL Pi SDK call!
│       └── test/
│           └── psypi_core_test.gleam        # ❌ Only hello_world_test
│
├── src/kernel/                               # TypeScript layer (ACTUAL)
│   ├── services/
│   │   ├── ai/                               # ❌ Fake AI system (to be replaced)
│   │   │   ├── AIProvider.ts
│   │   │   ├── OpenRouterProvider.ts
│   │   │   ├── GLM5Provider.ts
│   │   │   └── ...
│   │   ├── InnerAgentExecutor.ts            # ❌ Uses fake AI
│   │   ├── PiSDKExecutor.ts                 # ✅ Has REAL Pi SDK!
│   │   ├── InterReviewService.ts            # ❌ Uses fake AI
│   │   └── AgentIdentityService.ts          # ✅ Working identity system
│   └── index.ts                              # Kernel class
│
└── src/agent/extension/
    └── extension.ts                          # ✅ Pi extension with tools
```

### The Gap

```
┌─────────────────────────────────────────────────────────────┐
│  TypeScript Layer (WORKING)                                 │
│  - InterReviewService uses AIProvider (fake)               │
│  - PiSDKExecutor has real Pi SDK (unused by Gleam)         │
│  - AgentIdentityService works                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ ❌ NO CONNECTION
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Gleam Layer (ORPHANED)                                     │
│  - partner.gleam has placeholder implementations           │
│  - partner_ffi.mjs has REAL Pi SDK call (unused!)          │
│  - No TypeScript imports these modules                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Detailed File Analysis

### 2.1 Gleam Files

#### psypi_core.gleam - ⭐⭐⭐☆☆

**What it does well:**
```gleam
// ✅ Good type definitions
pub type SessionID { SessionID(value: String) }
pub type AgentID { AgentID(value: String, prefix: String) }

// ✅ Proper validation with Result type
pub fn new_session_id(uuid: String) -> Result(SessionID, String) {
  case string.length(uuid) {
    len if len >= 32 -> Ok(SessionID(value: uuid))
    _ -> Error("Invalid UUID: must be at least 32 characters")
  }
}
```

**What's missing:**
- No JSON encoding/decoding (traenupi has `jsonx.gleam`)
- No validation module (traenupi has `validation.gleam`)
- No tests for these types

#### partner.gleam - ⭐⭐☆☆☆

**Critical Issues:**
```gleam
// ❌ Custom PResult instead of built-in Result
pub type PResult(a, e) {
  POk(a)
  PError(e)
}

// ❌ Placeholder implementations
pub fn get_or_create(identity_value: String, _identity_prefix: String) 
    -> PResult(String, String) {
  // TODO: Call FFI to check existing session  <-- TODO!
  POk("psypi-partner-session-" <> identity_value)  // <-- Mock!
}

pub fn heartbeat(_session_id: String) -> PResult(Nil, String) {
  // TODO: Update heartbeat in DB via FFI  <-- TODO!
  POk(Nil)
}
```

**Problems:**
1. Uses custom `PResult` instead of Gleam's `Result` type
2. 5 TODO comments = incomplete implementation
3. No actual FFI calls to TypeScript
4. No error handling

#### partner_ffi.mjs - ⭐⭐⭐☆☆

**Hidden Gem - This file has REAL Pi SDK integration!**
```javascript
// ✅ REAL Pi SDK call!
import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";

export async function create_pi_session(identity) {
  try {
    if (typeof initTheme === 'function') {
      await initTheme();  // ✅ Proper initialization
    }
    
    // ✅ Real Pi agent session creation!
    const result = await createAgentSession({
      context: { 
        role: 'permanent-partner', 
        project: 'psypi',
        identityId: identity.value || identity
      }
    });
    
    return { 
      type: "POK", 
      value: result.session?.id || "session-created"
    };
  } catch (error) {
    return { type: "PERROR", value: error.message };
  }
}
```

**But this file is NEVER imported anywhere in TypeScript!**

### 2.2 TypeScript Files

#### InnerAgentExecutor.ts - The "Fake AI"

```typescript
// ❌ Uses fake AI provider
export class InnerAgentExecutor {
  private readonly provider: AIProvider;

  static async create(db: DatabaseClient): Promise<InnerAgentExecutor> {
    const provider = await AIProviderFactory.createInnerProvider(db);
    return new InnerAgentExecutor(provider);
  }

  async executeTask(prompt: string, timeoutMs: number = 300000): Promise<TaskResult> {
    // ❌ Calls fake AI
    const result = await this.provider.complete(prompt);
    // ...
  }
}
```

**This should be replaced with Gleam's `partner.gleam` + `PiSDKExecutor`!**

#### PiSDKExecutor.ts - The Real Pi SDK

```typescript
// ✅ Has REAL Pi SDK integration
export class PiSDKExecutor {
  async executeWithPrompt(systemPrompt: string, task: string): Promise<PiTaskResult> {
    const { createAgentSession, DefaultResourceLoader, SessionManager } = 
      await import('@mariozechner/pi-coding-agent');
    
    const { session } = await createAgentSession({
      resourceLoader: loader,
      sessionManager: SessionManager.inMemory(),
      cwd: this.cwd,
    });
    
    await session.prompt(task);
    // ...
  }
}
```

**This is what should be called from Gleam FFI!**

#### InterReviewService.ts - 1200+ lines

```typescript
// ❌ Uses fake AI provider
export class InterReviewService extends EventEmitter {
  private readonly aiProvider: AIProvider;

  static async create(db: DatabaseClient): Promise<InterReviewService> {
    const aiProvider = await AIProviderFactory.createInnerProvider(db);  // ❌ Fake!
    return new InterReviewService(db, aiProvider, getSessionId);
  }

  private async callAI(systemPrompt: string, userPrompt: string): Promise<string> {
    const response = await this.aiProvider.complete(userPrompt, systemPrompt);  // ❌ Fake!
    return response.content;
  }
}
```

**This should use Gleam for validation and state management!**

---

## 3. Specific Integration Points Needed

### 3.1 Create `src/kernel/services/GleamBridge.ts`

**This file DOES NOT EXIST but should:**

```typescript
// src/kernel/services/GleamBridge.ts
// THIS FILE NEEDS TO BE CREATED!

import {
  get_or_create,
  heartbeat,
  terminate,
  type PartnerSession,
} from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs';

import { PiSDKExecutor } from './PiSDKExecutor.js';
import { DatabaseClient } from '../db/DatabaseClient.js';

export class GleamBridge {
  private db: DatabaseClient;
  private piExecutor: PiSDKExecutor;

  constructor(db: DatabaseClient) {
    this.db = db;
    this.piExecutor = new PiSDKExecutor();
  }

  async getOrCreatePartnerSession(identityId: string): Promise<string> {
    // Call Gleam function
    const result = await get_or_create(identityId, 'P');
    
    if (result.type === 'POK') {
      return result.value;
    }
    
    throw new Error(`Failed to create partner session: ${result.value}`);
  }

  async executeWithPartner(prompt: string, systemPrompt?: string): Promise<string> {
    const sessionId = await this.getOrCreatePartnerSession('default');
    
    // Use real Pi SDK
    const result = await this.piExecutor.executeWithPrompt(
      systemPrompt || 'You are a helpful AI coding assistant.',
      prompt
    );
    
    return result.output;
  }
}
```

### 3.2 Modify `InterReviewService.ts`

**Current (lines 60-65):**
```typescript
static async create(db: DatabaseClient, getSessionId?: () => string | null): Promise<InterReviewService> {
  const aiProvider = await AIProviderFactory.createInnerProvider(db);  // ❌ Fake!
  const service = new InterReviewService(db, aiProvider, getSessionId);
  // ...
}
```

**Should be:**
```typescript
static async create(db: DatabaseClient, getSessionId?: () => string | null): Promise<InterReviewService> {
  // ✅ Use Gleam + real Pi SDK
  const gleamBridge = new GleamBridge(db);
  const service = new InterReviewService(db, gleamBridge, getSessionId);
  // ...
}
```

### 3.3 Fix `partner.gleam`

**Current:**
```gleam
pub fn get_or_create(identity_value: String, _identity_prefix: String) 
    -> PResult(String, String) {
  // TODO: Call FFI to check existing session
  POk("psypi-partner-session-" <> identity_value)
}
```

**Should be:**
```gleam
import gleam/result.{type Result, Ok, Error}

pub type SessionError {
  NotFound
  DatabaseError(String)
  PiSDKError(String)
}

pub fn get_or_create(identity_value: String, identity_prefix: String) 
    -> Result(String, SessionError) {
  case check_existing_session(identity_value) {
    Ok(Some(session_id)) -> Ok(session_id)
    Ok(None) -> create_new_session(identity_value, identity_prefix)
    Error(err) -> Error(DatabaseError(err))
  }
}

@external(javascript, "./partner_ffi.mjs", "create_pi_session")
fn create_pi_session_ffi(identity: String) -> Promise(Result(String, String))

fn create_new_session(identity: String, prefix: String) -> Result(String, SessionError) {
  // Call FFI to create real Pi session
  let result = create_pi_session_ffi(identity)
  // Handle promise and return result
}
```

---

## 4. Missing Modules (Compared to traenupi)

| Module | traenupi | psypi | Purpose |
|--------|----------|-------|---------|
| jsonx.gleam | ✅ 200+ lines | ❌ Missing | JSON encoding/decoding |
| json_path.gleam | ✅ 150+ lines | ❌ Missing | JSON Path queries |
| schema.gleam | ✅ 300+ lines | ❌ Missing | JSON Schema validation |
| schema_builder.gleam | ✅ 280+ lines | ❌ Missing | Schema to JSON conversion |
| validation.gleam | ✅ 100+ lines | ❌ Missing | Input validation |
| resultx.gleam | ✅ 80+ lines | ❌ Missing | Result/Option combinators |
| async.gleam | ✅ 100+ lines | ❌ Missing | Promise utilities |
| logger.gleam | ✅ 80+ lines | ❌ Missing | Structured logging |
| config.gleam | ✅ 100+ lines | ❌ Missing | Config file parsing |
| http.gleam | ✅ 120+ lines | ❌ Missing | HTTP client |
| fs.gleam | ✅ 80+ lines | ❌ Missing | File system utilities |
| datetime.gleam | ✅ 150+ lines | ❌ Missing | Date/time handling |
| str.gleam | ✅ 100+ lines | ❌ Missing | String utilities |
| cache.gleam | ✅ 200+ lines | ❌ Missing | TTL and LRU cache |
| collection.gleam | ✅ 150+ lines | ❌ Missing | Queue, Stack, Deque |

**Recommendation**: Copy these modules from traenupi as a starting point.

---

## 5. Test Comparison

| Project | Test File | Test Count | Coverage |
|---------|-----------|------------|----------|
| traenupi | traenupi_core_test.gleam | 343 tests | Comprehensive |
| psypi | psypi_core_test.gleam | 1 test | Placeholder |

**psypi's only test:**
```gleam
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"
  assert greeting == "Hello, Joe!"
}
```

**What tests are needed:**
```gleam
// Missing tests for SessionID
pub fn session_id_validation_test() {
  let result = new_session_id("too-short")
  should.equal(result, Error("Invalid UUID: must be at least 32 characters"))
}

// Missing tests for AgentID
pub fn agent_id_parsing_test() {
  let result = parse_agent_id("S-psypi-myproject")
  should.equal(result, Ok(AgentID(value: "S-psypi-myproject", prefix: "S")))
}

// Missing tests for partner functions
pub fn get_or_create_test() {
  // Test session creation
}
```

---

## 6. Action Plan (Prioritized)

### Phase 1: Connect Existing Code (2-3 hours)

1. **Create `GleamBridge.ts`** - Import compiled Gleam modules
2. **Build Gleam project** - Run `gleam build` to generate `.mjs` files
3. **Add import test** - Verify TypeScript can import Gleam output

### Phase 2: Replace Fake AI (4-6 hours)

1. **Modify `InterReviewService.ts`** - Use GleamBridge instead of AIProvider
2. **Connect `partner_ffi.mjs`** - Link to real PiSDKExecutor
3. **Update `InnerAgentExecutor.ts`** - Replace with Gleam + Pi SDK

### Phase 3: Add Missing Modules (6-8 hours)

1. **Copy jsonx.gleam from traenupi** - JSON handling
2. **Copy validation.gleam from traenupi** - Input validation
3. **Copy resultx.gleam from traenupi** - Result combinators
4. **Copy schema.gleam from traenupi** - JSON Schema validation

### Phase 4: Add Tests (4-6 hours)

1. **Add tests for psypi_core.gleam** - SessionID, AgentID
2. **Add tests for partner.gleam** - Session management
3. **Add integration tests** - TypeScript ↔ Gleam

---

## 7. Specific Code Fixes Needed

### Fix 1: Build Gleam and verify output

```bash
cd gleam/psypi_core
gleam build
# Should create: build/dev/javascript/psypi_core/
```

### Fix 2: Create TypeScript bridge

```typescript
// src/kernel/services/GleamBridge.ts (NEW FILE)
import * as psypiCore from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core.mjs';
import * as partner from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs';

export { psypiCore, partner };
```

### Fix 3: Update partner.gleam to use proper Result

```gleam
// Change from:
pub type PResult(a, e) { POk(a) PError(e) }

// To:
// Use built-in Result type
pub type SessionError {
  NotFound
  DatabaseError(String)
  PiSDKError(String)
}

pub fn get_or_create(...) -> Result(String, SessionError) {
  // ...
}
```

### Fix 4: Connect FFI to real TypeScript services

```javascript
// partner_ffi.mjs - Add database connection
import { DatabaseClient } from '../../../kernel/db/DatabaseClient.js';

export async function query_db(query) {
  const db = DatabaseClient.getInstance();
  const result = await db.query(query);
  return { type: "POK", value: result.rows };
}
```

---

## 8. Key Findings Summary

### What's Working

1. **Documentation is excellent** - GLEAM_INTEGRATION.md, PLAN-inner-ai-to-pi-agent-GLEAM.md
2. **FFI has real Pi SDK** - partner_ffi.mjs imports and calls `@mariozechner/pi-coding-agent`
3. **TypeScript has real Pi SDK** - PiSDKExecutor.ts has working implementation
4. **Identity system works** - AgentIdentityService.ts is functional

### What's Broken

1. **Gleam and TypeScript are disconnected** - No imports anywhere
2. **partner.gleam has placeholders** - 5 TODO comments, mock implementations
3. **Fake AI still in use** - InterReviewService uses AIProviderFactory
4. **No tests** - Only 1 placeholder test

### The Hidden Gem

**partner_ffi.mjs** has working Pi SDK code that's never used:
```javascript
const result = await createAgentSession({
  context: { role: 'permanent-partner', project: 'psypi' }
});
```

This should be the foundation for the "permanent partner" feature!

---

## 9. Conclusion

The psypi project has **excellent documentation** and a **working FFI with real Pi SDK integration**, but the **Gleam and TypeScript layers are completely disconnected**. The `partner_ffi.mjs` file is a hidden gem that has working Pi SDK code, but it's orphaned.

**Key Insight**: The project doesn't need to write new Gleam code from scratch. It needs to:
1. **Connect** the existing Gleam FFI to TypeScript
2. **Replace** the fake AI provider with the real Pi SDK
3. **Add** the missing utility modules from traenupi

**Estimated Time to Fix**: 16-24 hours of focused work

**Priority Order**:
1. 🔴 Create `GleamBridge.ts` and verify imports work
2. 🔴 Build Gleam and verify `.mjs` output
3. 🟡 Replace `AIProviderFactory.createInnerProvider()` with Gleam + Pi SDK
4. 🟡 Add missing modules (jsonx, validation, resultx, schema)
5. 🟢 Add comprehensive tests

---

## 10. Comparison with traenupi

| Aspect | traenupi | psypi |
|--------|----------|-------|
| Gleam Modules | 18+ modules | 2 modules |
| Tests | 343 tests | 1 test |
| TypeScript Integration | ✅ Full | ❌ None |
| JSON Handling | ✅ jsonx, json_path, schema | ❌ Missing |
| Validation | ✅ validation.gleam | ❌ Missing |
| Documentation | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ |
| Production Use | ✅ Yes | ❌ No |

**traenupi is a working reference implementation** that psypi should follow.

---

**Review Completed**: 2026-05-03  
**Reviewer**: Trae AI (TraeNuPI)  
**Next Step**: Create `GleamBridge.ts` and run `gleam build`

---

## 11. Quick Start Implementation Guide

### Step 1: Build Gleam and Verify Output (5 min)

```bash
cd /Users/jk/gits/hub/tools_ai/psypi/gleam/psypi_core
gleam build
gleam test

# Verify output exists:
ls -la build/dev/javascript/psypi_core/
# Should see:
# - psypi_core.mjs
# - psypi_core/
#   - partner.mjs
```

### Step 2: Create GleamBridge.ts (15 min)

Create file: `src/kernel/services/GleamBridge.ts`

```typescript
import * as partner from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core/partner.mjs';
import * as psypiCore from '../../gleam/psypi_core/build/dev/javascript/psypi_core/psypi_core.mjs';
import { PiSDKExecutor } from './PiSDKExecutor.js';
import { DatabaseClient } from '../db/DatabaseClient.js';
import { logger } from '../utils/logger.js';

export interface PartnerSession {
  id: string;
  status: 'alive' | 'dead' | 'pending';
  createdAt: Date;
}

export class GleamBridge {
  private static instance: GleamBridge;
  private db: DatabaseClient;
  private piExecutor: PiSDKExecutor | null = null;

  private constructor(db: DatabaseClient) {
    this.db = db;
  }

  static getInstance(): GleamBridge {
    if (!GleamBridge.instance) {
      GleamBridge.instance = new GleamBridge(DatabaseClient.getInstance());
    }
    return GleamBridge.instance;
  }

  async getOrCreatePartnerSession(identityId: string): Promise<PartnerSession> {
    try {
      // Call Gleam function via FFI
      const result = await partner.get_or_create(identityId, 'P');
      
      if (result.type === 'POK') {
        return {
          id: result.value,
          status: 'alive',
          createdAt: new Date(),
        };
      }
      
      throw new Error(`Failed to create partner session: ${result.value}`);
    } catch (error) {
      logger.error('[GleamBridge] Failed to get/create partner session', { error });
      throw error;
    }
  }

  async executeWithPartner(prompt: string, systemPrompt?: string): Promise<string> {
    if (!this.piExecutor) {
      this.piExecutor = new PiSDKExecutor();
    }

    const session = await this.getOrCreatePartnerSession('default');
    logger.info('[GleamBridge] Using partner session', { sessionId: session.id });

    const result = await this.piExecutor.executeWithPrompt(
      systemPrompt || 'You are a helpful AI coding assistant.',
      prompt
    );

    return result.output;
  }

  async heartbeat(sessionId: string): Promise<boolean> {
    try {
      const result = await partner.heartbeat(sessionId);
      return result.type === 'POK';
    } catch (error) {
      logger.error('[GleamBridge] Heartbeat failed', { sessionId, error });
      return false;
    }
  }
}

export const gleamBridge = GleamBridge.getInstance();
```

### Step 3: Fix partner.gleam (30 min)

Update file: `gleam/psypi_core/src/psypi_core/partner.gleam`

```gleam
import gleam/result.{type Result, Ok, Error}
import gleam/string
import gleam/dict.{type Dict}

// Session status enum
pub type SessionStatus {
  Alive
  Dead
  Pending
}

// Proper error type (instead of generic String)
pub type SessionError {
  NotFound
  DatabaseError(String)
  PiSDKError(String)
  InvalidIdentity(String)
}

// Session record
pub type PartnerSession {
  PartnerSession(
    id: String,
    status: SessionStatus,
    identity_id: String,
    created_at: Int,
    last_heartbeat: Int,
  )
}

// FFI declarations - these call partner_ffi.mjs
@external(javascript, "./partner_ffi.mjs", "create_pi_session")
fn create_pi_session_ffi(identity: String) -> Promise(Result(String, String))

@external(javascript, "./partner_ffi.mjs", "update_heartbeat")
fn update_heartbeat_ffi(session_id: String) -> Promise(Result(Nil, String))

@external(javascript, "./partner_ffi.mjs", "query_db")
fn query_db_ffi(query: String) -> Promise(Result(Dict(String, dynamic.Dynamic), String))

// Public API: Get or create a partner session
pub fn get_or_create(identity_value: String, identity_prefix: String) 
    -> Promise(Result(String, SessionError)) {
  
  // Validate identity
  case validate_identity(identity_value) {
    Error(err) -> promise.resolve(Error(err))
    Ok(_) -> {
      // Check existing session first
      case check_existing_session(identity_value) {
        Ok(Some(session_id)) -> promise.resolve(Ok(session_id))
        Ok(None) -> create_new_session(identity_value, identity_prefix)
        Error(err) -> promise.resolve(Error(DatabaseError(err)))
      }
    }
  }
}

// Public API: Send heartbeat
pub fn heartbeat(session_id: String) -> Promise(Result(Nil, SessionError)) {
  promise.map(
    update_heartbeat_ffi(session_id),
    fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(err) -> Error(PiSDKError(err))
      }
    }
  )
}

// Internal: Validate identity format
fn validate_identity(identity: String) -> Result(Nil, SessionError) {
  case string.length(identity) {
    len if len < 3 -> Error(InvalidIdentity("Identity too short"))
    len if len > 100 -> Error(InvalidIdentity("Identity too long"))
    _ -> Ok(Nil)
  }
}

// Internal: Check if session already exists
fn check_existing_session(identity: String) -> Result(Option(String), String) {
  // TODO: Query database via FFI
  Ok(None)
}

// Internal: Create new session via Pi SDK
fn create_new_session(identity: String, prefix: String) 
    -> Promise(Result(String, SessionError)) {
  promise.map(
    create_pi_session_ffi(identity),
    fn(result) {
      case result {
        Ok(session_id) -> Ok(session_id)
        Error(err) -> Error(PiSDKError(err))
      }
    }
  )
}
```

### Step 4: Update partner_ffi.mjs (15 min)

Update file: `gleam/psypi_core/src/psypi_core/partner_ffi.mjs`

```javascript
import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";
import { DatabaseClient } from '../../../kernel/db/DatabaseClient.js';

// FFI: Create Pi session - calls real Pi SDK
export async function create_pi_session(identity) {
  console.log("[FFI] create_pi_session called with:", identity);
  
  try {
    // Initialize theme first (required by Pi SDK)
    if (typeof initTheme === 'function') {
      await initTheme();
    }
    
    // Create real Pi agent session
    const result = await createAgentSession({
      context: { 
        role: 'permanent-partner', 
        project: 'psypi',
        identityId: identity.value || identity
      }
    });
    
    console.log("[FFI] Pi session created:", result.session?.id);
    
    return { 
      type: "Ok", 
      value: result.session?.id || "session-created"
    };
  } catch (error) {
    console.error("[FFI] Pi SDK failed:", error.message);
    return { type: "Error", value: error.message };
  }
}

// FFI: Update heartbeat in database
export async function update_heartbeat(session_id) {
  try {
    const db = DatabaseClient.getInstance();
    await db.query(
      `UPDATE partner_sessions SET last_heartbeat = NOW() WHERE id = $1`,
      [session_id]
    );
    return { type: "Ok", value: null };
  } catch (error) {
    return { type: "Error", value: error.message };
  }
}

// FFI: Query database
export async function query_db(query) {
  try {
    const db = DatabaseClient.getInstance();
    const result = await db.query(query);
    return { type: "Ok", value: result.rows };
  } catch (error) {
    return { type: "Error", value: error.message };
  }
}
```

### Step 5: Add Tests (30 min)

Update file: `gleam/psypi_core/test/psypi_core_test.gleam`

```gleam
import gleeunit
import gleeunit/should
import psypi_core.{type SessionID, type AgentID, new_session_id, new_agent_id}

pub fn main() {
  gleeunit.main()
}

// === SessionID Tests ===

pub fn session_id_valid_test() {
  let result = new_session_id("a".repeat(32))
  should.be_ok(result)
}

pub fn session_id_too_short_test() {
  let result = new_session_id("too-short")
  should.be_error(result)
}

pub fn session_id_empty_test() {
  let result = new_session_id("")
  should.be_error(result)
}

// === AgentID Tests ===

pub fn agent_id_valid_test() {
  let result = new_agent_id("S-psypi-myproject", "S")
  should.be_ok(result)
  
  case result {
    Ok(id) -> {
      should.equal(id.value, "S-psypi-myproject")
      should.equal(id.prefix, "S")
    }
    Error(_) -> Nil
  }
}

pub fn agent_id_empty_prefix_test() {
  let result = new_agent_id("test-id", "")
  should.be_error(result)
}

// === Identity Validation Tests ===

pub fn identity_too_short_test() {
  let result = validate_identity("ab")
  should.be_error(result)
}

pub fn identity_too_long_test() {
  let long_id = "a".repeat(101)
  let result = validate_identity(long_id)
  should.be_error(result)
}

pub fn identity_valid_test() {
  let result = validate_identity("valid-identity")
  should.be_ok(result)
}
```

### Step 6: Update InterReviewService.ts (30 min)

Update file: `src/kernel/services/InterReviewService.ts`

```typescript
// Add import at top
import { gleamBridge } from './GleamBridge.js';

// In static create() method, replace:
// const aiProvider = await AIProviderFactory.createInnerProvider(db);
// With:
// Use GleamBridge for AI calls

// In callAI() method, replace:
// const response = await this.aiProvider.complete(userPrompt, systemPrompt);
// With:
private async callAI(systemPrompt: string, userPrompt: string): Promise<string> {
  return gleamBridge.executeWithPartner(userPrompt, systemPrompt);
}
```

---

## 12. Verification Checklist

After implementation, verify:

```bash
# 1. Gleam builds successfully
cd gleam/psypi_core && gleam build && gleam test

# 2. TypeScript compiles
cd ../.. && npm run build

# 3. GleamBridge can be imported
node -e "import('./build/kernel/services/GleamBridge.js').then(m => console.log('✅ GleamBridge imports OK'))"

# 4. Partner session creation works
node -e "
import('./build/kernel/services/GleamBridge.js').then(async ({ gleamBridge }) => {
  const session = await gleamBridge.getOrCreatePartnerSession('test-identity');
  console.log('✅ Session created:', session.id);
});
"

# 5. Tests pass
npm test
```

---

## 13. Decision: Modify vs Delete

| Approach | Time | Risk | Keeps Working Code |
|----------|------|------|-------------------|
| **Modify (Recommended)** | 16-24h | Low | ✅ Yes |
| Delete & Re-do | 20-30h | Medium | ❌ No |

**Recommendation: Modify existing code.** The `partner_ffi.mjs` file has working Pi SDK integration that would take significant time to re-implement correctly.
