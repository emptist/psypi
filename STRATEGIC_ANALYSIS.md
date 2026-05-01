# Psypi Strategic Analysis: Why It Feels Separated

Generated: 2026-05-01

## The Core Question

**Why does psypi feel "somewhat separated" even though it's supposed to be a unified whole?**

The answer: **The merger was structural (files moved) but not architectural (design unified).**

---

## Evidence of Separation

### Layer 1: Code Organization
```
src/
├── kernel/     # Nezha heritage (database, services, CLI)
├── agent/      # NuPI heritage (extension, db.ts)
└── cli.ts      # Yet another entry point
```

Two separate worlds coexist with minimal integration.

### Layer 2: Entry Points
- `src/cli.ts` - Commander-based, uses Kernel singleton
- `src/kernel/cli/index.ts` - Raw argv parsing, used by kernel internally

Two different CLI paradigms, unclear relationship.

### Layer 3: Database Access
- Fixed: Now uses DatabaseClient singleton
- But: The pattern of "kernel has DB layer, agent has db.ts" still exists architecturally

### Layer 4: Identity & Attribution
- AgentIdentityService exists but was hardcoded
- The concept of "who is doing what" wasn't cleanly unified

---

## Strategic Question: What IS psypi?

### Three Possible Visions

| Vision | Description | Current State |
|--------|-------------|---------------|
| **A: Platform** | Multi-agent coordination system | Database supports this, architecture doesn't |
| **B: Single Agent** | One AI assistant | Architecture suggests this, database doesn't |
| **C: Library** | Reusable components | Not structured this way at all |

**Current state: Trying to be all three without committing to any.**

---

## Three Strategic Problems

### Problem 1: The Interface Problem

**Who is psypi's user?**

| User Type | Current Interface | Issue |
|-----------|-------------------|-------|
| Human developers | CLI (src/cli.ts) | Works |
| AI agents | Kernel class methods | Inconsistent with CLI |
| External systems | ??? | No clear API |

**Missing: A unified interface layer**
- One clear API for all consumers
- CLI is just a thin wrapper over the API
- Kernel is the implementation, not the interface

---

### Problem 2: The Data Model Problem

**Is psypi ONE agent or a PLATFORM for multiple agents?**

Evidence for Platform:
- `agent_identities` table
- Multiple agents in database (psypi, nupi, traenupi, piano, etc.)
- Agent tracking via `created_by`, `agent_id` columns

Evidence for Single Agent:
- One Kernel class
- One CLI
- No multi-tenancy model

**Missing: Clear multi-tenancy model**
- If platform: Need agent isolation, permissions, quotas
- If single agent: Remove complexity of agent identity tracking

---

### Problem 3: The Execution Model Problem

**Who orchestrates work?**

```
Current Flow (Unclear):
┌─────────────────┐
│  CLI (cli.ts)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────────┐
│ Kernel (index)  │◄────│ Agent Extension  │
└─────────────────┘     └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│    Services     │     │    Pi SDK        │
└─────────────────┘     └──────────────────┘
```

Questions:
- Is Kernel the orchestrator or just a library?
- Should agent/extension be a plugin to Kernel?
- Or should Kernel be a service that agent/extension calls?

**Missing: Clear execution architecture**

---

## Three Possible Paths Forward

### Path A: Full Unification (Platform Vision) ✅ Recommended

**Commit to being a multi-agent platform.**

Changes:
- Create `src/api/` - unified API layer
- Kernel becomes internal implementation detail
- Agent/extension becomes a plugin system
- Define agent isolation and permissions model
- Clear tenant boundaries

Pros:
- Clean architecture
- Scalable to many agents
- Matches database design

Cons:
- Major refactoring effort
- More complex initially

---

### Path B: Focused Single Agent (Tool Vision)

**Simplify to being ONE AI assistant.**

Changes:
- Remove agent identity complexity
- Merge kernel/ and agent/ into unified structure
- Single execution model
- Simpler mental model

Pros:
- Easier to understand
- Simpler to maintain

Cons:
- Loses multi-agent capability
- Wastes existing database design

---

### Path C: Explicit Separation (Library Vision)

**Split into focused packages.**

Changes:
- `@psypi/kernel` - database, services (reusable)
- `@psypi/agent` - execution, autonomy
- `@psypi/cli` - unified command interface

Pros:
- Flexible, can be used independently
- Clear module boundaries

Cons:
- More packages to maintain
- Doesn't solve integration problem

---

## Strategic Questions to Answer

### 1. Identity Question
**Is psypi a platform for multiple AI agents, or a single AI assistant?**

### 2. Interface Question
**What is the primary interface?**
- CLI for humans?
- API for AI agents?
- Library for developers?

### 3. Execution Question
**Who orchestrates work?**
- Kernel as orchestrator?
- Agent/extension as orchestrator?
- External caller (traenupi) as orchestrator?

### 4. Migration Question
**What's the end state for traenupi?**
- Should it call psypi CLI?
- Should it import psypi as library?
- Should it be merged INTO psypi?

---

## Recommended Architecture (Path A)

```
┌─────────────────────────────────────────────────────┐
│                    psypi Platform                    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │   CLI       │  │    API      │  │  WebSocket  │ │
│  │ (thin wrap) │  │  (primary)  │  │  (future)   │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │
│         │                │                │        │
│         └────────────────┼────────────────┘        │
│                          ▼                         │
│  ┌───────────────────────────────────────────────┐ │
│  │              Core Services Layer              │ │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐        │ │
│  │  │ TaskSvc │ │ MemSvc  │ │ IssueSvc│ ...    │ │
│  │  └─────────┘ └─────────┘ └─────────┘        │ │
│  └───────────────────────────────────────────────┘ │
│                          │                         │
│                          ▼                         │
│  ┌───────────────────────────────────────────────┐ │
│  │              Database Layer                   │ │
│  │         (DatabaseClient singleton)            │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
├─────────────────────────────────────────────────────┤
│                   Agent Plugins                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ traenupi │ │  piano   │ │  future  │           │
│  └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────┘
```

---

## Immediate Actions

### Phase 1: Clarify Vision (Now)
1. Decide: Platform vs Single Agent vs Library
2. Document the decision in ARCHITECTURE.md
3. Create a roadmap for the chosen path

### Phase 2: API Layer (Next)
1. Create `src/api/` directory
2. Define core API interfaces
3. Migrate CLI to use API layer
4. Migrate agent/extension to use API layer

### Phase 3: Plugin System (Future)
1. Define agent plugin interface
2. Migrate traenupi to plugin model
3. Enable third-party agent plugins

---

## Clarification (2026-05-01)

**Key insight from project owner:**
- **traenupi is just for Trae IDE** - don't over-index on it
- **psypi = NuPI + Nezha bundled together** - ONE thing, not two

This means **Path B (Single Agent)** is correct, not Path A (Platform).

### The Real Problem

The "separation" is just **naming and organization**, not fundamental architecture:
- `kernel/` directory name implies "I am a kernel for others" - but psypi IS the whole thing
- `agent/` directory name implies "I am a separate component" - but it's just part of psypi
- Historical naming (Nezha, NuPI) still in code creates mental separation

### The Fix (Much Simpler)

1. **Rename directories:**
   - `kernel/` → `core/` or dissolve into root
   - `agent/` → `execution/` or `tools/`

2. **Remove historical references:**
   - No more "Nezha" or "NuPI" in code/comments
   - Just "psypi"

3. **Simplify identity:**
   - `agent_identities` is just for attribution (tracking who did what)
   - NOT multi-tenancy or platform features

## Conclusion

Psypi feels separated because **directory names and historical references create artificial boundaries**.

**Recommendation: Rename and simplify** to reflect that psypi is ONE AI agent with database + execution built-in.

This is much simpler than adding API layers or plugin systems - it's just about removing the mental separation that shouldn't exist.
