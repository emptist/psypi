# Pi Tool Blocked Protection

## What Causes Tools to Be Blocked

In Pi, tools can be blocked by returning `{ block: true, message: "..." }` from the `tool_call` hook.

## Our Protection: Dangerous Pattern Blocking

We intentionally block dangerous operations in `unified_tool_call_hook()`:

```javascript
const dangerousPatterns = [
  { pattern: /spawn.*pi/i, message: 'Hint: Spawning Pi causes infinite loop...' },
  { pattern: /spawn.*psypi/i, message: 'Hint: Spawning psypi causes infinite loop...' },
  { pattern: /rm.*-rf/i, message: 'Hint: Recursive delete is dangerous...' },
  { pattern: /git.*push.*force/i, message: 'Hint: Force push is dangerous...' },
  { pattern: /DROP.*TABLE/i, message: 'Hint: DROP TABLE is destructive...' },
  { pattern: /DELETE.*FROM.*WHERE/i, message: 'Hint: DELETE without LIMIT is dangerous...' },
];
```

## What NOT to Do

### 1. Never Return `{ block: true }` for Normal Cases

```javascript
// ❌ WRONG - blocks all tools
pi.on('tool_call', async (event, ctx) => {
  return { block: true, message: 'Blocked!' };
});

// ✅ CORRECT - only block dangerous patterns
pi.on('tool_call', async (event, ctx) => {
  if (isDangerous(event)) {
    return { block: true, message: 'Dangerous!' };
  }
  // Return nothing to allow normal execution
});
```

### 2. Never Throw from Hooks

```javascript
// ❌ WRONG - throws and might block
pi.on('before_agent_start', async (event, ctx) => {
  throw new Error('Something went wrong');
});

// ✅ CORRECT - catch errors, log, don't block
pi.on('before_agent_start', async (event, ctx) => {
  try {
    await riskyOperation();
  } catch (e) {
    console.error('Error:', e.message);
  }
});
```

### 3. Hooks Should Return Correct Types

For `before_agent_start`, return should be:
```javascript
// ✅ CORRECT format
return { systemPrompt: 'modified prompt' };

// ❌ WRONG - returns block (will block everything!)
return { systemPrompt: '...', block: true };
```

## Conditions That Cause Blocking

| Condition | Cause | Prevention |
|-----------|-------|------------|
| Dangerous pattern match | tool_call returns `{ block: true }` | Intentional safety |
| Undefined function | Missing import or build error | Always rebuild after Gleam changes |
| DB schema mismatch | Missing column/table | Use migrations |
| Hook throws | Uncaught exception in hook | Wrap in try/catch |
| Wrong return type | Returning block when not intended | Test hooks before deploy |

## Safe Hook Pattern

```javascript
pi.on('before_agent_start', async (event, ctx) => {
  try {
    // Safe operations only
    const notifs = await get_pending_notifications();
    if (notifs.length > 0) {
      return {
        systemPrompt: event.systemPrompt + '\n\n' + formatAlerts(notifs)
      };
    }
  } catch (e) {
    // Log but don't block - let Worker continue
    console.error('before_agent_start error:', e.message);
  }
  // Return nothing = normal flow
});
```

## Current Hooks (Safe)

Our hooks in `extension_generator.gleam` are designed to never accidentally block:

| Hook | Return | Safe? |
|------|--------|-------|
| `tool_call` | `{ block: true }` only for dangerous patterns | ✅ Only intentional blocks |
| `session_start` | Nothing (async fire-and-forget) | ✅ |
| `before_agent_start` | `{ systemPrompt: ... }` or nothing | ✅ |
| `agent_start` | Nothing | ✅ |
| `agent_end` | Nothing | ✅ |
| `tool_result` | Nothing | ✅ |

## When Modifying Hooks

### ❌ DON'T Return `block: true` Unintentionally

```javascript
// Before modifying, understand what the hook expects
// before_agent_start expects: { systemPrompt: string } or undefined
// tool_call expects: { block: true, message: string } or undefined
```

### ❌ DON'T Mix Return Types

```javascript
// ❌ WRONG - mixing types
pi.on('before_agent_start', async (event, ctx) => {
  if (error) {
    return { block: true, message: 'Error!' };  // WRONG type!
  }
  return { systemPrompt: '...' };
});

// ✅ CORRECT - consistent return types
pi.on('before_agent_start', async (event, ctx) => {
  if (error) {
    console.error('Error:', error);
    return;  // Let normal flow continue
  }
  return { systemPrompt: '...' };
});
```

## Testing: Verify No Accidental Blocking

1. Run `psypi`
2. Execute a simple tool like `psypi-my-id`
3. If blocked, check console for errors

If tools get blocked unexpectedly, it's likely:
- A Gleam build error (undefined function)
- A hook throwing an uncaught exception
- A DB connection failure