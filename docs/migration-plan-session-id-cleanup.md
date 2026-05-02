# Psypi Session ID 统一与清理迁移计划

**日期**: 2026-05-02  
**状态**: 分析阶段（只读，未执行）

---

## 1. Session ID 的唯一定义（来自 Pi 官方文档）

### 1.1 Pi Session 文件结构

根据 Pi 官方文档 (`session-format.md` 和 `sessions.md`)：

**文件位置**:
```
~/.pi/agent/sessions/--<path>--/<timestamp>_<uuid>.jsonl
```

**示例**:
```
~/.pi/agent/sessions/--Users-jk-gits-hub-tools_ai-psypi--/2026-05-02T09-52-46-678Z_019de81a-d855-7479-9c71-37ee9f1105c3.jsonl
```

**Session ID 定义**:
- **Session ID = UUID 部分**（文件名中的 UUID）
- 示例：`019de81a-d855-7479-9c71-37ee9f1105c3`
- 该 UUID 也存储在 JSONL 文件的 `SessionHeader` 的 `id` 字段中

**重要更正**:
- ❌ 用户提到的 `~/.py/agent/sessions/` 是拼写错误
- ✅ 正确路径是 `~/.pi/agent/sessions/`（注意是 `.pi` 不是 `.py`）

### 1.2 从 Pi 文档确认的关键信息

从 `session-format.md`:
```json
{"type":"session","version":3,"id":"uuid","timestamp":"...","cwd":"/path/to/project"}
```

- Session 文件的 `header` 中的 `id` 字段就是 Session ID
- 这个 ID 是 UUID 格式（当前是 UUID v7，时间有序）
- 文件名格式：`<timestamp>_<uuid>.jsonl`

### 1.3 AGENT_SESSION_ID 环境变量

**来源**:
- Pi TUI 在启动 AI agent（扩展）时自动设置此环境变量
- 值 = 当前 Pi session 的 UUID（见上文）

**用途**:
- 让 agent（如 psypi 扩展）知道自己运行在哪个 Pi session 中
- psypi 的 `extension.ts` 中使用它来查询 `agent_sessions` 表

**验证**:
```bash
# 在 Pi TUI 中运行时，可以通过以下方式查看
echo $AGENT_SESSION_ID
```

---

## 2. Kernel 方法分析（src/kernel/index.ts）

### 2.1 startSession(agentType?)

**当前实现**:
```typescript
async startSession(agentType?: string) {
  const agentId = agentType || await this.getAgentId();
  const sessionId = process.env.AGENT_SESSION_ID || `session_${Date.now()}`;
  await this.query(
    `INSERT INTO agent_sessions (id, agent_type, started_at) 
     VALUES ($1, $2, NOW()) 
     ON CONFLICT DO NOTHING`,
    [sessionId, agentId]
  );
  return sessionId;
}
```

**分析**:
- **意图**: 在 `agent_sessions` 表中注册一个 session
- **问题**:
  1. 如果 `AGENT_SESSION_ID` 存在，会尝试插入一个 UUID（正确）
  2. 如果不存在，生成一个 `session_${Date.now()}`（格式不统一）
  3. `ON CONFLICT DO NOTHING` - 如果 session 已存在，不做任何事
  4. **混淆**: `agentType` 参数实际上被期待是 `agentId`（语义错误）

**使用场景**:
- CLI 命令 `psypi session-start` 调用此方法
- 问题：Pi 扩展启动时会自动设置 `AGENT_SESSION_ID`，不需要手动 start？

**结论**: 
- ⚠️ **可能无用**: Pi 自己管理 session，psypi 不需要再"start"一个 session
- 如果要用，应该只记录 session 与 agent identity 的关联

---

### 2.2 endSession(sessionId?)

**当前实现**:
```typescript
async endSession(sessionId?: string) {
  const id = sessionId || process.env.AGENT_SESSION_ID || 'unknown';
  await this.query(
    `UPDATE agent_sessions SET status = 'ended', last_heartbeat_at = NOW() WHERE id = $1`,
    [id]
  );
}
```

**分析**:
- **意图**: 标记 session 结束
- **问题**:
  1. `agent_sessions` 表中的 session 是 "fake" 的 `bot_` ID
  2. 真正的 Pi session ID (UUID) 可能从未被插入到 `agent_sessions` 表
  3. 所以这条 UPDATE 可能什么都匹配不到

**使用场景**:
- CLI 命令 `psypi session-end` 调用此方法
- 问题：Pi session 结束时，Pi 自己会处理，psypi 需要监听吗？

**结论**:
- ⚠️ **可能无用**: 如果 `agent_sessions` 表要被废弃，这个方法也没用了

---

### 2.3 getContext()

**当前实现**:
```typescript
async getContext() {
  const agentId = await this.getAgentId();
  const agentType = agentId;  // ❌ 混淆：agentType 应该是 agentId
  const sessionId = process.env.AGENT_SESSION_ID || 'unknown';
  
  const tasks = await this.query("SELECT COUNT(*) as count FROM tasks WHERE status = 'PENDING'");
  const issues = await this.query("SELECT COUNT(*) as count FROM issues WHERE status = 'open'");
  
  return {
    agentType,
    sessionId,
    pendingTasks: parseInt(tasks.rows[0].count),
    openIssues: parseInt(issues.rows[0].count),
  };
}
```

**分析**:
- **意图**: 返回当前 agent 的上下文信息
- **问题**:
  1. `agentType` 被错误地设置为 `agentId`（应该叫 `agentId`）
  2. `sessionId` 来自环境变量，如果未设置则显示 'unknown'
  3. 这个方法被 `psypi context` CLI 命令调用

**实际输出** (`psypi context`):
```
📊 PSYPI CONTEXT

🤖 Agent: S-psypi-psypi
Session: S-psypi-psypi  ← ❌ 这是 Agent ID，不是 Session ID！
Tasks: 373 pending
Issues: 1019 open
```

**问题根源**:
- `src/cli.ts` 中的 `psypi context` 命令调用了 `kernel.getContext()`
- 但 `getContext()` 返回的 `sessionId` 没有被正确使用
- CLI 显示的是 `agentId` 而不是 `sessionId`

**结论**:
- ✅ **有用但需要修正**: 
  - 修正 `getContext()` 的返回字段命名
  - 确保 CLI 正确显示 Session ID (UUID)
  - 如果 `AGENT_SESSION_ID` 未设置，应该显示 'no-active-session' 而不是 'unknown'

---

## 3. process.env.AGENT_SESSION_ID 分析

### 3.1 是什么？

- **定义**: Pi TUI 在启动 agent（扩展）时设置的环境变量
- **格式**: UUID（例如 `019de81a-d855-7479-9c71-37ee9f1105c3`）
- **来源**: Pi 的 session 管理系统

### 3.2 从哪里来？

**Pi 内部机制**（从 Pi 源码推测）:
1. Pi TUI 启动时创建或恢复一个 session
2. Session ID 存储在 JSONL 文件的 header 中
3. 当 Pi 启动扩展（如 psypi）时，将当前 session ID 通过环境变量 `AGENT_SESSION_ID` 传递给扩展
4. 扩展可以通过此变量知道自己在哪个 Pi session 中运行

**验证方法**:
```typescript
// 在 psypi extension.ts 中
console.log('AGENT_SESSION_ID:', process.env.AGENT_SESSION_ID);
```

### 3.3 是否有用？

**✅ 非常有用！**

**用途**:
1. **追踪**: 知道哪个 psypi 操作是由哪个 Pi session 发起的
2. **审计**: 在 `tasks`, `issues`, `memory` 等表中记录 `session_id`，可以追溯操作来源
3. **关联**: 将 psypi 的数据库记录与 Pi 的 session 文件关联起来

**当前问题**:
- psypi 的 `agent_sessions` 表使用了 fake 的 `bot_` ID
- 真正的 Pi session ID (UUID) 没有被正确存储和使用
- `extension.ts` 中虽然读取了 `AGENT_SESSION_ID`，但查询的是 `agent_sessions` 表（存的是 `bot_` ID），所以可能查不到

---

## 4. 发现的问题总结

### 4.1 关键问题

| 问题 | 位置 | 严重程度 |
|------|------|----------|
| **Session ID 定义混乱** | 整个项目 | 🔴 高 |
| **Fake `bot_` IDs** | `agent_sessions` 表, `AgentSessionService.ts` | 🔴 高 |
| **`psypi context` 显示错误的 Session ID** | `src/cli.ts`, `kernel/index.ts` | 🟠 中 |
| **`startSession/endSession` 可能无用** | `kernel/index.ts` | 🟡 低 |
| **`getContext()` 字段命名错误** | `kernel/index.ts` | 🟡 低 |

### 4.2 "Stupid AI" 遗留的错误

**位置**: `src/cli.ts` 第 401 行
```typescript
// 错误的代码（"stupid AI" 修改的）
const sessionId = (await AgentIdentityService.getResolvedIdentity()).id;

// 正确的代码（应该恢复为）
const sessionId = process.env.AGENT_SESSION_ID || 'unknown-session';
```

**影响**: `psypi my-session-id` 命令返回的是 Agent ID，不是 Session ID

---

## 5. 迁移计划（待执行）

### Phase 1: 统一 Session ID 定义
1. ✅ **确认**: Session ID = Pi session UUID（来自 `~/.pi/agent/sessions/...jsonl` 文件名）
2. 📝 **文档**: 在项目文档中明确此定义
3. 🔄 **替换**: 将所有 "session ID" 引用统一到此定义

### Phase 2: 清理 Fake IDs
1. ❌ **废弃**: `agent_sessions` 表中的 `bot_` ID
2. ✅ **迁移**: 如果有用，改为存储真实的 Pi session UUID
3. 🗑️ **删除**: `AgentSessionService.ts` 中的 `generateBotId()` 函数
4. 🗑️ **删除**: 数据库迁移 `050_agent_sessions.sql` 中的 `generate_bot_id()` 函数

### Phase 3: 修正 Kernel 方法
1. ✅ **修正** `getContext()`:
   - 字段改名: `agentType` → `agentId`
   - 正确返回 `sessionId`（来自 `AGENT_SESSION_ID`）
2. ❓ **评估** `startSession/endSession`:
   - 如果无用，标记为 `@deprecated` 或删除
   - 如果有用，改为使用真实的 Pi session UUID
3. ✅ **修正** `psypi context` CLI 命令:
   - 显示正确的 Session ID (UUID)
   - 如果未设置，显示 'no-active-session'

### Phase 4: 修正 CLI 错误
1. ✅ **恢复** `src/cli.ts` 第 401 行:
   ```typescript
   const sessionId = process.env.AGENT_SESSION_ID || 'unknown-session';
   ```

### Phase 5: 数据库迁移
1. 📝 **创建迁移**: `076_cleanup_fake_session_ids.sql`
2. 🔄 **更新**: `tasks`, `memory`, `inter_reviews` 表的 `session_id` 字段
   - 从 `VARCHAR(50)` (存 `bot_*`) 改为 `UUID` (存 Pi session UUID)
3. 🗑️ **清理**: 删除 `agent_sessions` 表（如果确认无用）

---

## 6. 附录：相关文件清单

### 需要修改的文件
- `src/kernel/index.ts` - 修正 `getContext()`, 评估 `startSession/endSession`
- `src/cli.ts` - 修正 `my-session-id` 命令, 修正 `context` 命令显示
- `src/agent/extension/extension.ts` - 确认 `AGENT_SESSION_ID` 的使用
- `src/kernel/services/AgentSessionService.ts` - 删除或重写

### 需要废弃/删除的文件
- `src/kernel/db/migrations/050_agent_sessions.sql` - 包含 `generate_bot_id()`
- `src/kernel/services/AgentSessionService.ts` - 如果确认无用

### 参考文档
- Pi 官方文档: `session-format.md`, `sessions.md`
- 项目文档: `AGENTS.md`, `PROJECT_CONTEXT.md`

---

**下一步**: 等待用户确认此分析是否正确，再执行迁移计划。
