# New World Plan: A/S Dual-Worker Architecture

**Date:** 2026-05-15
**Status:** Planning

---

## Vision

psypi becomes a truly autonomous AI system:
- **S-worker** (Somatic): Does the actual work — coding, file edits, tool calls
- **A-worker** (Autonomic): Monitors, decides, preserves knowledge, directs S when idle
- They share the same session, same context, same database
- A adapts behavior based on context pressure

---

## What We Know Works

- Identity system (S-/A- IDs) ✅
- Database tools (tasks, issues, meetings, skills) ✅
- Gleam core (type-safe, <100 lines/module) ✅
- Pi extension generator (auto-generates extension.js) ✅
- `psypi-commit` (explicit A+S collaboration) ✅
- `psypi-consult-autonomic` (S asks A for advice) ✅

---

## What We Need to Build

### 1. Context-Aware A-Trigger (HIGH PRIORITY)

**Hook: `before_agent_start`**

This is where A injects directives into S's system prompt.

```gleam
// In src/generator/before_agent_start.gleam

pub fn handler_body() -> String {
  // 1. Check context usage
  // 2. Query pending directives from DB
  // 3. If no directives, A decides whether to create one
  // 4. Format and inject into system prompt
}
```

**A's decision based on context remaining:**

| Context Left | A's Action |
|--------------|------------|
| < 10% | PRESERVE: update docs, code review, git commit |
| 10-30% | CONSOLIDATE: summarize work, create directive, commit |
| 30-70% | COLLABORATE: review with S, ask questions, suggest work |
| > 70% | PLAN: evaluate tasks/issues, set directives |

### 2. Compaction History (HIGH PRIORITY)

**Hook: `session_compact`**

Save compaction summaries to database so knowledge survives context exhaustion.

```sql
CREATE TABLE compaction_history (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    summary text NOT NULL,
    tokens_before integer,
    session_id text,
    created_at timestamptz DEFAULT now()
);
```

### 3. A-Worker SOUL (MEDIUM PRIORITY)

Define A's personality and decision-making framework in the `souls` table.

A's SOUL should encode:
- Decision priorities (preserve > consolidate > collaborate > plan)
- Communication style (concise, actionable directives)
- Areas of focus (code quality, documentation, task management)

### 4. Directive System Enhancement (MEDIUM PRIORITY)

Current directives table exists but is barely used. Enhance:
- Priority levels (critical, high, medium, low)
- Expiration (directives auto-expire after N hours)
- Context (directives carry context about why they were created)
- Acknowledgment (S marks directives as acknowledged/complete)

### 5. User Presence Detection (LOW PRIORITY)

Simple timeout-based detection:
- Track last user input timestamp
- User considered "absent" after N minutes of no input
- A only acts autonomously when user is absent

---

## Implementation Order

### Phase 1: Foundation
1. Create `compaction_history` table (migration)
2. Implement `session_compact` hook to save summaries
3. Implement `before_agent_start` hook (basic directive injection)

### Phase 2: Intelligence
4. Implement A's context-aware decision logic
5. Enhance directive system with priority/expiration
6. Add compaction history queries for A's context

### Phase 3: Autonomy
7. Implement user presence detection
8. Implement A's SOUL definition
9. Test 24/7 autonomous operation

---

## Key Principles

1. **Simplicity**: Each hook does one thing well
2. **Type safety**: All Gleam code uses proper types, no raw strings
3. **Database as shared state**: A and S communicate through DB, not direct calls
4. **Context-aware**: A adapts behavior based on remaining context
5. **Preserve knowledge**: Compaction summaries save what matters

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/generator/before_agent_start.gleam` | Rewrite: inject directives based on context |
| `src/generator/session_compact.gleam` | New: save compaction summary to DB |
| `src/compaction_history.gleam` | New: DB operations for compaction history |
| `src/directive.gleam` | Enhance: add priority, expiration, context |
| `src/soul.gleam` | Enhance: add A's SOUL definition |
| `src/migrations/*.sql` | New: compaction_history table |
| `AGENTS.md` | Update: document new architecture |
