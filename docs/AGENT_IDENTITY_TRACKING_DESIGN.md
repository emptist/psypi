# Agent Identity — Single Source of Truth

## 核心原则

1. **`AgentIdentity` 类型是唯一因** — 所有关于"我是谁"的信息都在这个类型里
2. **数据库是存放结果的地方，不是查询的来源** — Gleam 不查 DB 来获取身份，而是把计算好的结果存进去
3. **session_id 是 `AgentIdentity` 的内在属性** — agent_id 的最后一部分就是 session_id，不需要单独传递
4. **任何需要身份的地方，都必须通过 `get_resolved_identity` 获取** — 不直接读 DB，不硬编码

---

# Agent Identity Tracking Design

## Implemented Features

### ✅ Tracking Status

| Tracking Layer | Table | Trigger | Status |
|---------------|-------|---------|--------|
| Activity | `activity_log` | Every tool call | ✅ Implemented |
| Auto-tracking | `activity_log` | Via extension.js generator | ✅ Implemented |
| Session | `agent_sessions` | Session start | ⏳ Future |

### How It Works

**1. ID Trigger Point** (Always active):
- Every call to `get_resolved_identity()` automatically logs to `activity_log`
- Records: `agent_id`, `activity="get_resolved_identity"`, context with parameters

**2. Auto Tool Tracking** (Implemented):
- Modified `extension_generator.gleam` to auto-inject tracking
- Every Pi tool call automatically logs to `activity_log`
- Records: `agent_id`, `activity="tool_call"`, context with tool name, params, success

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Two Trigger Points                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ID Trigger                   Event Trigger                 │
│  get_resolved_identity()     Pi Tool (via extension.js)    │
│         │                            │                      │
│         └────────────┬───────────────┘                      │
│                      ↓                                      │
│              activity_log table                             │
│         (agent_id, activity, context)                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

```
Pi ctx.sessionManager.getSessionId()
        │
        ▼ (一次性传入)
get_resolved_identity(permanent, session_id, project, ...)
        │
        ▼ (封装进类型)
AgentIdentity { id, session_id, project, source, ... }
        │
        ├──► activity_log (ID Trigger: "get_resolved_identity")
        │
        └──► 返回给 JS，后续所有操作从 identity 中取 id
            │
            ├──► activity_log (Event Trigger: "tool_call")
            └──► 其他需要 agent_id 的地方
```

## Implementation Details

### 1. Gleam Module: agent_identity.gleam
- Modified `get_resolved_identity` to call `activity_log.log_activity`
- Logs: `agent_id`, `activity="get_resolved_identity"`, context with all parameters

### 2. Generator: extension_generator.gleam
- Added `trackActivity()` helper function
- Added `log_activity` import
- Every tool auto-calls `trackActivity(toolName, params, result)`

### 3. Generated Code: extension.js
- Imports: `get_resolved_identity`, `log_activity`
- Each tool executes: Gleam call → unwrap result → trackActivity()

## Database Records

```sql
-- ID Trigger
agent_id: S-psypi-psypi
activity: get_resolved_identity
context: {"model": "", "source": "psypi", "project": "psypi", "permanent": false, "session_id": ""}

-- Tool Trigger  
agent_id: S-psypi-psypi
activity: tool_call
context: {"tool": "psypi-tasks", "params": {"status": "pending"}, "success": true}
```

## Future Enhancements

- Session tracking via `agent_sessions` table
- Detailed activity tracking via Pi Tool: `psypi-log-activity(action, context)`
- Event-based tracking system

## Files Modified

| File | Change |
|------|--------|
| `agent_identity.gleam` | Added activity_log call |
| `extension_generator.gleam` | Added auto-tracking code |
| `extension.js` | Regenerated with tracking |

The key insight is that **regardless of how it's triggered, the underlying logic is the same**:

```gleam
// Unified emission function
emit_activity(
  actor: AgentIdentity,      // WHO (always required)
  action: String,            // WHAT (what happened)
  target: Option(Target),    // WHICH (optional)
  context: JSON             // DETAILS (optional)
)
```

This follows Functional Programming principles:
- Core function does one thing (return identity)
- Side effects are handled by separate functions (emit_activity)
- Implementation can change anytime without affecting callers

## Two Trigger Points

| Trigger Point | When | Session_ID Source |
|--------------|------|-------------------|
| **ID Trigger** | `get_resolved_identity()` called | JS 从 ctx 获取，传一次给 Gleam |
| **Event Trigger** | Pi tool `execute` 时 | 从 `AgentIdentity` 对象中取（不碰 ctx） |

ID Trigger 记录 "获取了身份"，Event Trigger 记录 "执行了什么工具操作"。

### ID Trigger
- JS 从 Pi 的 `ctx.sessionManager.getSessionId()` 获取 session_id
- 调用 `get_resolved_identity(permanent, session_id, ...)`
- Gleam 把 session_id 封装进 `AgentIdentity`，同时写入 activity_log
- 从此时起，session_id 就在 `AgentIdentity` 里，不再单独传递

### Event Trigger
- JS 从缓存的 `AgentIdentity` 对象中取 `identity.id`
- 调用 `log_activity(identity.id, "tool_call", context)`
- **不再碰 ctx**，不需要 `trackActivity` 函数

## PiToolSpec — Gleam 端的 Tool 定义

每个 Pi tool 在 Gleam 里用一个 `PiToolSpec` 描述：

```gleam
pub type PiToolSpec {
  PiToolSpec(
    name: String,           // "psypi-my-id"
    description: String,    // "Get current agent ID"
    parameters: String,     // TypeBox schema 的 JS 字符串
    import: String,         // Gleam 模块导入路径
    function: String,       // Gleam 函数名
    args: List(PiCallArg),  // 参数列表
  )
}
```

`extension_generator.gleam` 读取 `List(PiToolSpec)`，生成符合 Pi API 要求的 `extension.js`。

生成的 `extension.js` 结构固定：
1. import Gleam 编译出的 `.mjs` 模块
2. `unwrapGleamResult` helper（处理 Gleam 的 Ok/Error）
3. 每个 tool 调用 `pi.registerTool({ name, description, parameters, execute })`
4. `execute` 内部 await Gleam 函数，unwrap 结果，返回 `{ content: [...] }`

**关键点：** `_ctx` 只在需要 session_id 的工具里使用（`psypi=my-id`, `psypi-partner-id`），其他工具不需要碰 `_ctx`。

## Implementation Status

### ✅ Step 1: DONE - Add emit_activity to activity_log module
- Activity_log module already had `log_activity` function

### ✅ Step 2: DONE - Modify get_resolved_identity to trigger activity logging
- Modified `agent_identity.gleam` to call `activity_log.log_activity` after getting identity
- Logs: agent_id, activity="get_resolved_identity", context with all parameters

### ✅ Step 3: DONE - Test the implementation
- Build: SUCCESS
- Test: SUCCESS
- Verified activity_log has new record

### ⏳ Step 4: (Future) Add event trigger via Pi Tool
- Add psypi-log-activity tool
- Connect to emit_activity

### Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `activity_log.gleam` | Modify | Add emit_activity function |
| `agent_identity.gleam` | Modify | Call emit_activity after getting identity |

### Code Changes

#### activity_log.gleam - Add emit_activity

```gleam
pub fn emit_activity(
  actor: AgentIdentity,
  action: String,
  target: Option(String),
  context: String,
) -> promise.Promise(Result(Nil, ActivityLoggingError)) {
  // Insert into activity_log
  // ...
}
```

#### agent_identity.gleam - Trigger on get_resolved_identity

```gleam
pub fn get_resolved_identity(...) {
  // Existing logic to get identity
  let identity = ...
  
  // NEW: Emit activity (fire and forget - don't block)
  emit_activity(identity, "get_resolved_identity", None, "{...}")
  
  identity
}
```

## Future Extension

### Future: Detailed Activity Tracking via Pi Tools or Events

The current design is a **simple foundation**. In the future, detailed AI activity tracking could be implemented via:

- **Pi Tools**: Create tools like `psypi-log-activity(activity_type, context)` that AI can call
- **Events**: Emit events when AI performs actions, with event listeners logging to activity_log

This allows:
- More granular tracking (what exactly the AI is doing)
- Better context (tool parameters, results, etc.)
- Extensible (add new activity types without code changes)

### Current Implementation (Simple Foundation)

For now, implement the basic tracking:
- Every call to `get_resolved_identity` logs one activity record
- This establishes the tracking mechanism
- Future extensions can build on this infrastructure
