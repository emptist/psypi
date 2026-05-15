# Simple A-Worker: Ask S 2 Questions

**Design:** At `before_agent_start`, A checks if S was idle. If yes, A asks S 2 questions.

---

## The Mechanism

`BeforeAgentStartEvent` fires after user submits prompt but before agent loop.

A checks `ctx.isIdle()`:
- `true` → S was idle (not working) → A injects 2 questions
- `false` → S is still working → A stays silent

```typescript
// BeforeAgentStartEventResult
interface BeforeAgentStartEventResult {
    systemPrompt?: string;  // Replace system prompt for this turn
}
```

A returns a modified system prompt with 2 questions appended.

---

## Flow

```
User sends message
  → before_agent_start fires
    → A checks ctx.isIdle()
      │
      ├─ true (S was idle)
      │   ├─ A reads session context (what S was doing)
      │   ├─ A selects 2 questions
      │   └─ A returns modified system prompt with questions
      │
      └─ false (S was working)
          └─ A returns nothing (no injection)
  → S wakes up
    → Sees questions in system prompt (if any)
    → Answers them naturally
    → Continues working
```

---

## A's Question Selection

A reads recent session entries to understand what S was doing, then picks 2 questions:

| S's Recent Activity | Question 1 | Question 2 |
|---------------------|------------|------------|
| Code changes | What was the most important change? | Is there anything you'd change? |
| Bug fix | What was the root cause? | What should I remember? |
| Task completion | What did you accomplish? | What's next? |
| Stuck/blocked | What's blocking you? | What do you need? |
| Learning | What's the key insight? | How does this affect our approach? |
| Nothing recent | What should I work on? | Any blockers? |

---

## System Prompt Injection Format

```
[Before you continue, I have 2 questions about your recent work:]

1. <question 1>
2. <question 2>

[Please answer them briefly, then continue with your work.]
```

---

## Implementation Steps (龟兔赛跑)

### Step 1: Basic Hook
- Create `before_agent_start` handler
- Check `ctx.isIdle()`
- If idle, append 2 generic questions to system prompt
- Test: Does S see the questions?

### Step 2: Context-Aware Questions
- Read recent session entries
- Select questions based on what S was doing
- Test: Are questions relevant?

### Step 3: Save Q&A
- Save questions and answers to database
- Build knowledge base over time
- Test: Can A reference past Q&A?

---

## Key Principle

**A only speaks when S is idle.** Never interrupt S while working.
