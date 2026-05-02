# Psypi Session ID 统一清理计划

**日期**: 2026-05-02  
**状态**: ✅ 已完成（commit 42f4887）  
**原则**: Session ID 只有一个真相源，只有一个获取函数，一个 Pi 工具

---

## 核心决策

### Single Source of Truth
- **唯一真相源**: `process.env.AGENT_SESSION_ID`（由 Pi TUI 设置）
- **前提**: psypi 只在 Pi 运行时运行，因此该环境变量必然存在
- **无 fallback**: 如果不存在，说明 bug，直接抛异常

### 唯一入口
- **唯一函数**: `kernel.piSessionID()`
- **唯一工具**: `psypi-piSessionID`
- **唯一变量名**: `sessionID`（代码）或 `session_id`（数据库）

---

## 实施记录

### ✅ Phase 1: Kernel 修改 (`src/kernel/index.ts`)
- 删除: `getContext()`, `startSession()`, `endSession()`
- 添加: `piSessionID()` 函数

### ✅ Phase 2: Extension 修改 (`src/agent/extension/extension.ts`)
- 删除: `SESSION_ID` 常量
- 添加: `psypi-piSessionID` 工具
- 修改: 所有 `process.env.AGENT_SESSION_ID` → `await kernel.piSessionID()`

### ✅ Phase 3: CLI 修改 (`src/cli.ts`)
- 删除: `context`, `session-start`, `session-end` 命令
- 修改: `my-session-id` 命令调用 `kernel.piSessionID()`

### ✅ Phase 4: 清理无用代码
- 删除: `AgentSessionService.ts`, `050_agent_sessions.sql`
- 修改: `AgentIdentityService.ts`, `Config.ts` - 移除对 AgentSessionService 的引用

### ✅ Phase 5: 构建 & 提交
- 构建: 成功 (`pnpm build` ✓)
- 提交: `42f4887` on branch `clean-psypi`
- Inter-review 分数: 70/100

---

## 最终状态

✅ **唯一 Session ID 入口**: `kernel.piSessionID()`  
✅ **唯一 Pi 工具**: `psypi-piSessionID`  
✅ **唯一变量名**: `sessionID` (代码) 或 `session_id` (数据库)  
✅ **无 fallback**: 不存在就抛异常  
✅ **无无用函数**: `getContext()`, `startSession()`, `endSession()` 已删除  

---

## 验证清单

修改完成后，确保：

- ✅ **唯一读取 `process.env.AGENT_SESSION_ID` 的地方**: `piSessionID()` 函数内部
- ✅ **唯一对外的函数**: `kernel.piSessionID()`
- ✅ **唯一 Pi 工具**: `psypi-piSessionID`
- ✅ **无 fallback**: `piSessionID()` 不存在就抛异常
- ✅ **无 `startSession/endSession/getContext`**: 已删除
- ✅ **变量名统一**: `sessionID` 或 `session_id`

---

**实施完成日期**: 2026-05-02  
**Issue ID**: `b5e37247-5a0c-4ea1-aef0-32426b079476`  
**Commit**: `42f4887`
