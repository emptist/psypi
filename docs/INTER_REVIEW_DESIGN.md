# Inter-Review Design (Mode 3: End of Workflow)

## Overview

**KEY INSIGHT**: The key is INTELLIGENCE, not extension.js or automatic scripts.

Technical implementation (extension.js, Gleam, callMonitor) is just the medium. The intelligence is the core.

- Not: "we added a hook to extension.js"
- But: "we have an intelligent system that learns from every cell"

**CRITICAL**: Pre-commit review is MORE IMPORTANT than the commit itself in psypi system. It's not just a gate - it's a learning opportunity.

Inter-review is triggered when worker is ready to commit (`psypi-commit`). It asks Monitor to review the code changes before committing.

## Workflow (Strict with Review ID)

```
Worker writes code
        ↓
psypi-commit (request review, no ID yet)
        ↓
Monitor reviews → generates REVIEW_ID + PASS/FAIL + score
        ↓
   ┌────┴────┐
   ↓         ↓
 FAIL       PASS + REVIEW_ID
   ↓         ↓
Worker      psypi-commit --review-id=XYZ
fixes           ↓
   ↓      Monitor verifies ID is valid + recent
   ↓         ↓
retry ───→ git commit succeeds
```

**Key principles:**
- REVIEW_ID: unique, timestamped, from Monitor
- Strict: can't commit without valid recent ID
- Fair: each attempt gets fresh review (new ID)
- Audit trail: every commit has review ID logged

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

---

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

## Current State (as of 2026-05-10)

### Implemented ✅
- ✅ psypi-commit uses Monitor LLM (callMonitor, not external P-tencent)
- ✅ Context gathering (git diff)
- ✅ PASS/FAIL + score response
- ✅ Review ID system (UUID format, matches DB schema)
- ✅ Strict process: can't commit without valid review_id
- ✅ Safety hooks already implemented

### What's Done (Plan 10-02, 10-03)
- Phase 10-02: Basic inter-review with Monitor LLM
- Phase 10-03: Review ID system for audit trail

### Remaining (Expanded Monitor Roles)
- ❌ Instructions: teach tools/skills/workflow
- ❌ Statistics: model quality, language efficiency
- ❌ Self-design: find own jobs
- ❌ Learn mistakes: track patterns
- ❌ Proactive improvement: suggest education/skills

---

## Monitor Modes (for reference)

See docs/MONITOR_MODES.md - Mode 3 is end-of-workflow (this doc).

---

*Updated: 2026-05-10*
*Key insight: Pre-commit is not a gate - it's the most important learning/education opportunity in psypi*

*Analogy: Intelligent system-level QC done at cellular level - each commit is a "cell" being quality-checked, not just a final inspection at the top.*

*There is no standalone immune system separated from every cell - just as there is no separate Monitor from the workflow. Every interaction IS the immune system. Every review is personal AND system-wide learning.*

## Process Summary

```
# Step 1: Get review (no ID yet)
psypi-commit "my commit message"
→ Monitor reviews → PASS/FAIL + UUID

# Step 2: Commit with ID
psypi-commit "my commit message" --review-id=<UUID-from-step-1>
→ Verified → commit succeeds
```