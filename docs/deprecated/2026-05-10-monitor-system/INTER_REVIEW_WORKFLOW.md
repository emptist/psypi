# Inter-Review Workflow (Mode 3: End of Workflow)

## Current (Broken)
```
Agentbot → psypi-commit → inter_review → external LLM (P-tencent/hy3-preview)
                                      ↓
                              different system from Monitor
```

## Design
```
┌─────────────────────────────────────────────────────────────────┐
│                        WORKER                                  │
│                         writes code                             │
└───────────────────────────┬─────────────────────────────────────┘
                            ↓
              ┌─────────────────────────────┐
              │    psypi-commit (triggers)  │
              └──────────────┬──────────────┘
                             ↓
         ┌──────────────────────────────────────────────┐
         │              INTER_REVIEW                    │
         │                                              │
         │  1. Gather context:                          │
         │     - Changed files (git diff)               │
         │     - Commit message                         │
         │     - Recent activity                        │
         │                                              │
         │  2. Send to Monitor LLM                     │
         │     (same model as agentbot)                  │
         │                                              │
         │  3. Receive response:                        │
         │     - Score (0-100)                          │
         │     - PASS/FAIL                              │
         │     - Feedback comments                      │
         │                                              │
         └──────────────────────┬───────────────────────┘
                                ↓
                    ┌───────────┴───────────┐
                    │                       │
                 SCORE >= 70             SCORE < 70
                    │                       │
                    ↓                       ↓
            ┌───────────────┐      ┌─────────────────┐
            │ git commit    │      │ ❌ REJECTED     │
            │ ✅ SUCCESS    │      │ Agentbot sees     │
            │               │      │ score + feedback│
            └───────────────┘      │ Agentbot fixes    │
                                   │ Then retry      │
                                   └─────────────────┘
```

## What Monitor Needs for Review

### 1. Code Changes (THE WHAT)
- `git diff --name-only` - what files changed
- `git diff` - actual diff content
- Commit message

### 2. Context (THE WHY)
- **How** agentbot approached the changes
- **Why** certain decisions were made
- What was the original problem being solved?
- What constraints was agentbot under?
- This gives info about limitations to quality

### 3. Project Context
- Language/framework
- Recent learnings from this project
- Active skills that apply
- Project-specific rules (from docs/)

### 4. Safety Check Results
- Any dangerous operations blocked this session?

### 5. Activity Summary
- What did agentbot do this session?
- Patterns to watch for?

---

**Core insight**: Changes tell Monitor WHAT, context tells WHY.
Without context, Monitor judges code in isolation - unfair to agentbot.
With context, Monitor understands limitations and quality constraints.

## Key Points

1. **Trigger**: `psypi-commit` - agentbot ready to commit
2. **Gather context**: all of above (1-5)
3. **LLM**: Monitor (not external service) - uses same model as agentbot
4. **Output**: Score + PASS/FAIL + detailed feedback
5. **Decision**: 
   - Pass (≥70) → git commit
   - Fail → show feedback, agentbot fixes, retry

## What's Different from Current

| Aspect   | Current                          | New Design                 |
| -------- | -------------------------------- | -------------------------- |
| LLM      | External (P-tencent/hy3-preview) | Monitor (same as agentbot) |
| Context  | limited                          | full (git diff + activity) |
| Decision | stored in DB, async              | immediate sync             |
| Loop     | external polling                 | direct                     |