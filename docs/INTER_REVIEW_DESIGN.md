# Inter-Review Design (Mode 3: End of Workflow)

## Overview
Inter-review is triggered when worker is ready to commit (`psypi-commit`). It asks Monitor to review the code changes before committing.

**CRITICAL**: Pre-commit review is MORE IMPORTANT than the commit itself in psypi system. It's not just a gate - it's a learning opportunity.

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

## Monitor's Expanded Role in Inter-Review

### 1. Learn Worker Mistakes
- Track what mistakes workers frequently make
- Identify patterns in failures
- Feed back to improve education/skills/memory/rules system

### 2. Proactive Improvement
- Think about how to avoid mistakes
- Improve education (what to teach workers)
- Improve skills (what skills are missing)
- Improve memory (what to remember)
- Improve rules (project-specific guidelines)

### 3. Beyond Code Review - Give Instructions
- How to use basic psypi tools
- How to load appropriate skills
- How to change working order (e.g., "plan before doing")
- Workflow suggestions based on current task

### 4. Statistics & Analysis
- Model quality assessment
- Programming language efficiency
- Impact on correctness
- Code quality trends over time

### 5. Self-Design (Self-Initiated Jobs)
- Find more jobs to do
- Identify gaps in system
- Proactively improve psypi

---

## Monitor Modes (for reference)
See docs/MONITOR_MODES.md - Mode 3 is end-of-workflow (this doc).

---

*Updated: 2026-05-10*