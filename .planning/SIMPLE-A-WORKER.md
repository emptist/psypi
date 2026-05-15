# Simple A-Worker: Ask S 2 Questions

**Design:** At `before_agent_start`, A asks S exactly 2 questions. S answers and goes back to work.

---

## How It Works

```
S finishes working → agent_end fires
  → before_agent_start fires
    → A checks context, decides 2 questions
    → A injects questions into system prompt
  → S wakes up, sees questions, answers them
  → S continues working with A's context
```

---

## A's Decision Logic

A reads the session context and picks 2 questions from these categories:

### Category 1: Context Preservation (always relevant)
- "What was the most important thing you just accomplished?"
- "What should I make sure to remember for next time?"

### Category 2: Direction (when S might be stuck)
- "What's blocking you right now?"
- "What do you plan to work on next?"

### Category 3: Quality (when code was written)
- "Is there anything you'd change about what you just did?"
- "Are there any edge cases you haven't handled?"

### Category 4: Knowledge (when learning happened)
- "What's the key insight from this session?"
- "What would you tell your past self about this work?"

---

## Selection Rules

A picks 2 questions based on what S was doing:

| S's Recent Activity | Question 1 | Question 2 |
|---------------------|------------|------------|
| Code changes | What was the most important change? | Is there anything you'd change? |
| Bug fix | What was the root cause? | What should I remember for next time? |
| File creation | What's the purpose of this file? | Are there edge cases to handle? |
| Task completion | What did you accomplish? | What's the next task? |
| Stuck/blocked | What's blocking you? | What do you need to unblock? |
| Learning/research | What's the key insight? | How does this affect our approach? |

---

## Implementation

### Step 1: A reads session context

```gleam
// In before_agent_start handler
// Read recent session entries to understand what S was doing
// Check: file edits, tool calls, task completions, errors
```

### Step 2: A selects 2 questions

```gleam
// Simple pattern matching on recent activity
// Pick 2 questions from the appropriate category
```

### Step 3: A injects into system prompt

```gleam
// Format:
// [Autonomic] Before you continue, please answer:
// 1. <question 1>
// 2. <question 2>
//
// Your answers will help me understand your work better.
```

### Step 4: S answers and continues

S sees the questions in the system prompt, answers them naturally, and continues working. A reads the answers at the next `before_agent_start`.

---

## Why This Works

1. **Simple**: Only 2 questions, easy to implement
2. **Non-intrusive**: S answers naturally, no separate interaction
3. **Context-preserving**: A learns what S was thinking
4. **Adaptive**: Questions match what S was doing
5. **Gradual**: Can add more sophistication later

---

## Next Steps After This Works

1. Save A's questions and S's answers to database
2. Build a knowledge base from Q&A pairs
3. A starts making suggestions, not just asking
4. A starts setting directives based on patterns
5. Full autonomous operation
