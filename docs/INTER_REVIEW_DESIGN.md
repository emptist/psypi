# Inter-Review Design (Mode 3: End of Workflow)

## Overview
Inter-review is triggered when worker is ready to commit (`psypi-commit`). It asks Monitor to review the code changes before committing.

## Workflow
```
Worker writes code
        ↓
psypi-commit (trigger)
        ↓
┌───────────────┐
│ inter_review  │
│   (workflow)  │
└───────┬───────┘
        ↓
Monitor reviews (LLM)
        ↓
    Score + PASS/FAIL + Feedback
        ↓
   ┌────┴────┐
   ↓         ↓
 PASS      FAIL
   ↓         ↓
git    worker sees
commit feedback,
       fixes,
       retries
```

## What Monitor Needs

### 1. Code Changes (THE WHAT)
- `git diff --name-only` - what files changed
- `git diff` - actual diff content
- Commit message

### 2. Context (THE WHY) - CRITICAL
- How worker approached the changes
- Why certain decisions were made
- What was the original problem?
- What constraints was worker under?
- **Core**: Changes = WHAT, Context = WHY
- Without context, Monitor judges code in isolation - unfair

### 3. Project Context
- Language/framework
- Recent learnings from this project
- Active skills that apply
- Project-specific rules

### 4. Safety Check Results
- Any dangerous ops blocked this session?

### 5. Activity Summary
- What worker did this session
- Patterns to watch for

## Current State (needs fix)
- ❌ inter_review still calls external LLM (P-tencent/hy3-preview)
- ✅ Monitor has LLM capability via `callMonitor` in extension.js
- ✅ Safety hooks already implemented

## Implementation Plan
1. Move `psypi-commit` tool from inter_review.gleam → extension_generator.gleam (where callMonitor lives)
2. Implement context gathering (git diff, activity, project info)
3. Call callMonitor() with full context
4. Parse response for score/PASS/FAIL
5. Decision: pass → git commit, fail → show feedback

## Monitor Modes (for reference)
See docs/MONITOR_MODES.md - Mode 3 is end-of-workflow (this doc).

---

*Updated: 2026-05-10*