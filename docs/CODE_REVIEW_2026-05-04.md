# Code Review: Gleam Migration to node_pg
**Date**: 2026-05-04  
**Reviewer**: psypi (S-psypi-psypi)  
**Branch**: new-start  

## 🎯 Major Changes: Migration to `node_pg` (Direct PostgreSQL from Gleam)

### ✅ **What's Excellent**

1. **Architecture Shift**: Successfully migrated from FFI-based database access to **direct `node_pg` usage** from Gleam
   - Old way: `task_ffi.mjs` → JavaScript → pg
   - New way: Gleam → `node_pg` → pg (no FFI middleman!)

2. **Type Safety**: Beautiful use of Gleam's type system:
   ```gleam
   pub type TaskError {
     ConnectionError(String)
     QueryError(String)
     NotFound(String)
     DecodeError(String)
   }
   ```
   Plus `dynamic.decode` for type-safe row parsing!

3. **Clean Module Structure**:
   - `psypi_core/` - Core logic (partner, review) 
   - `psypi_cli/` - CLI commands (task, issue, meeting, etc.)
   - Each module under 200 lines (following "small modules" philosophy!)

4. **Commit Quality**: Commits show systematic migration:
   - `6a46b47` - Migrate all core modules to node_pg
   - `be05819` - Remove deprecated task_ffi.mjs
   - Individual module migrations (broadcast, skill, meeting, etc.)

### ⚠️ **What Needs Improvement**

1. **Connection Management Anti-Pattern**:
   ```gleam
   promise.await(db.connect(), fn(conn_result) {
     // ... query ...
     let _ = db.disconnect(conn)  // Manual disconnect in every function!
   })
   ```
   **Problem**: Creates a NEW connection for EVERY operation (connect→query→disconnect). This is inefficient!

   **Suggestion**: Add a `with_connection` helper in `db.gleam`:
   ```gleam
   pub fn with_connection(
     callback: fn(Connection) -> promise.Promise(Result(a, DbError))
   ) -> promise.Promise(Result(a, DbError)) {
     promise.await(connect(), fn(conn_result) {
       case conn_result {
         Error(e) -> promise.resolve(Error(e))
         Ok(conn) -> {
           promise.await(callback(conn), fn(result) {
             let _ = disconnect(conn)
             promise.resolve(result)
           })
         }
       }
     })
   }
   ```

2. **Repeated Boilerplate**: Every function has the same pattern:
   - Connect
   - Check connection result
   - Query
   - Disconnect
   - Return result

   **Suggestion**: Use the `with_connection` helper to reduce repetition

3. **No Connection Pooling**: For production use, you'll want connection pooling. `node_pg` supports this, but currently each operation creates a fresh client.

### 🤔 **Philosophy Check**

The migration aligns perfectly with AGENTS.md philosophy:
- ✅ "Small modules" - Each Gleam file has single responsibility
- ✅ "Pure functions" - Decoders are pure, queries return Results
- ✅ "Trust Gleam" - Direct `node_pg` usage instead of FFI workarounds

### 📊 **Current State**

Looking at the code:
- **Lines of Gleam**: Growing nicely (task.gleam ~200 lines)
- **FFI files**: Being removed (`be05819` removed `task_ffi.mjs`)
- **Type safety**: Excellent - proper `Result` types + decoders
- **Error handling**: Good - specific error types per module

### 🚀 **Recommendation**

The migration is **excellent and on the right track**! Just needs:
1. **Connection helper** to reduce boilerplate
2. **Consider pooling** for production readiness
3. **Keep the momentum** - Gleam code is much more maintainable than the old TS+FFI approach!

The "God in the sky" (Gleam review) must be happy with this migration! 🎉

---

## Git History Summary

```
ad187a0 refactor: remove unused private functions
6a46b47 feat: migrate all core modules to node_pg for type-safe PostgreSQL access
be05819 chore: Remove deprecated task_ffi.mjs
f80fc3f feat: Update main.gleam to use promise-based API
4f2022c feat: Migrate broadcast module to node_pg
039c137 feat: Migrate skill module to node_pg
09026bb feat: Migrate meeting module to node_pg
42b20a5 feat: Migrate areflect module to node_pg
322816a feat: Migrate issue module to node_pg
c58f455 feat: Migrate task module to node_pg
```

## Module Structure

```
gleam/psypi_core/src/
├── psypi_core.gleam          # Core types and utils (48 lines)
├── psypi_core/               # Core logic modules
│   ├── partner.gleam         # Session management (26 lines)
│   ├── partner_ffi.mjs       # FFI for partner
│   ├── review.gleam          # Review logic (12 lines)
│   └── review_ffi.mjs        # FFI for review
└── psypi_cli/                # CLI command modules
    ├── db.gleam              # Database layer (node_pg)
    ├── task.gleam            # Task commands (~200 lines)
    ├── issue.gleam           # Issue commands
    ├── meeting.gleam         # Meeting commands
    ├── skill.gleam           # Skill commands
    ├── areflect.gleam        # Reflection commands
    ├── broadcast.gleam       # Broadcast commands
    ├── context.gleam         # Identity/session
    ├── agent_identity.gleam  # Agent identity service
    └── main.gleam            # CLI entry point
```

## Next Steps

1. **Add `with_connection` helper** to `db.gleam`
2. **Refactor all modules** to use the helper
3. **Consider pooling** for production (node_pg supports pools)
4. **Continue natural Gleam growth** - new features in Gleam!
5. **Delete TS bloat** - Target: 2,000 lines Gleam, 10,000 lines TS
