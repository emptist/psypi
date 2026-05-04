# ✅ 正确流程：添加新 Pi 工具到 psypi

> **基于实际测试和经验总结（2026-05-04）**
> 
> 此文档修正了社区流传的错误语法和遗漏步骤。

---

## 🎯 核心原则（必须遵守！）

1. **先报告后修复** - "Report issues first, fix later"
2. **善用 Pi 写扩展** - "Ask Pi to WRITE EXTENSIONS for you!"
3. **用对 CLI 语法** - 不要相信网上的错误示例！

---

## 📋 完整正确流程

### 步骤 0: 阅读必要文档（很多人漏掉这步！）

```bash
# Pi 官方扩展文档（必须读！）
read ../refers/pi-mono/packages/coding-agent/docs/extensions.md

# psypi 特定的扩展请求指南
read docs/AI_GUIDE-requesting-pi-extensions.md

# 项目规则（必须读！）
read AGENTS.md
```

**为什么？** 不读文档会导致：
- 用错 API（Pi 扩展 vs psypi CLI）
- 遗漏关键配置（events, tools, permissions）
- 浪费时间在错误的方法上

---

### 步骤 1: 报告需求（使用正确的 CLI 语法！）

#### ❌ 错误语法（网上流传的）：
```bash
psypi issue-add "需要新工具" severity:high  # ❌ 错误！
```

#### ✅ 正确语法：
```bash
# 方法 1: 用 CLI（推荐，因为 psypi-issue-add 工具目前坏了）
psypi issue-add \
  --title "需要新的 Pi 工具: <功能描述>" \
  --severity high \
  --description "详细描述：为什么需要这个工具，它解决什么问题"

# 方法 2: 用 Pi 工具（等数据库修复后）
/psypi-issue-add \
  title:"需要新的 Pi 工具: <功能描述>" \
  severity:high
```

#### ⚠️ 当前已知问题（2026-05-04）：
```
psypi-issue-add 工具坏了！
错误: "column created_by of relation issues does not exist"
临时方案: 直接用 CLI (psypi issue-add --title ... --severity high)
```

---

### 步骤 2: 向 Pi 请求写扩展（提供完整信息！）

在 Pi TUI 中，用自然语言描述你的需求：

```
我想添加一个新的 Pi 工具到 psypi 扩展。

【功能需求】
- 工具名称: /psypi-<tool-name>
- 功能: <详细描述>
- 输入参数: <列出所有参数>
- 输出格式: <JSON/文本/表格>

【要 Hook 的事件】（可选）
- session_start: 启动时初始化
- tool_result: 监听工具结果
- file_changed: 监听文件变化
- custom_event: 自定义事件

【注册为】
- Pi 工具: 在 Pi TUI 中用 /psypi-<name> 调用
- 或后台服务: 监听事件自动执行

请帮我写扩展代码！
```

**为什么提供这么详细？** Pi 需要这些信息生成正确的扩展代码！

---

### 步骤 3: 保存扩展代码到正确位置

Pi 会生成扩展代码（TypeScript），你保存到：

#### 选项 A: 项目级扩展（推荐用于 psypi 专用工具）
```bash
# 保存到项目目录
.pi/extensions/your-tool.ts

# 或者（如果 .pi 不存在）
mkdir -p .pi/extensions
# 然后保存文件
```

#### 选项 B: 全局级扩展（适用于跨项目工具）
```bash
# 保存到用户目录
~/.pi/agent/extensions/your-tool.ts

# 确保目录存在
mkdir -p ~/.pi/agent/extensions
```

#### 扩展代码示例结构：
```typescript
// .pi/extensions/your-tool.ts
export default {
  name: 'psypi-your-tool',
  description: 'Tool description',
  
  // 注册 Pi 工具
  tools: [{
    name: 'psypi-your-tool',
    description: '...',
    parameters: { ... },
    handler: async (params, ctx) => {
      // 你的逻辑
      return { result: '...' };
    }
  }],
  
  // Hook 事件（可选）
  events: {
    session_start: async (ctx) => { ... },
    tool_result: async (result, ctx) => { ... }
  }
};
```

---

### 步骤 4: 在 Pi TUI 中重新加载

```bash
# 在 Pi TUI 中输入：
/reload

# 或者重启 Pi TUI：
# 1. 退出：Ctrl+C 或 /exit
# 2. 重新启动：psypi <命令>
```

**验证扩展是否加载：**
```bash
# 在 Pi TUI 中查看工具列表
/tools

# 应该能看到：psypi-your-tool
```

---

### 步骤 5: 测试工具

```bash
# 在 Pi TUI 中测试
/psypi-your-tool <参数>

# 或查看帮助
/psypi-your-tool --help
```

---

## 🚨 常见错误对照表

| 错误 | 正确 |
|------|------|
| `severity:high` | `--severity high` |
| `psypi issue-add "..." severity:high` | `psypi issue-add --title "..." --severity high` |
| 不读文档直接写代码 | 先读 `extensions.md` 和 `AI_GUIDE-*.md` |
| 保存到错误路径 | `.pi/extensions/` 或 `~/.pi/agent/extensions/` |
| 忘记 `/reload` | 改完扩展必须 `/reload` |

---

## 📌 当前系统状态（2026-05-04）

### ✅ 工作正常的工具：
- `/psypi-my-id` → 获取 agent ID
- `/psypi-partner-id` → 获取 partner ID
- `/psypi-status` → 查看系统状态
- `/psypi-tasks` → 列出任务
- `/psypi-project` → 查看项目信息
- `/psypi-autonomous` → 获取工作建议
- CLI: `psypi issue-add --title ...` (绕过坏的工具)

### ❌ 当前损坏的工具（等修复）：
- `/psypi-issue-add` → 数据库 schema 问题
- `/psypi-meeting-list` → 缺少 `completed_at` 列
- `/psypi-my-session-id` → 错误地声称 Pi TUI 未运行
- `/psypi-stats` → 解码错误
- `/psypi-visits` → 表不存在

---

## 🎯 快速检查清单

添加新工具前，确认：
- [ ] 已读 `extensions.md` 官方文档
- [ ] 已读 `AI_GUIDE-requesting-pi-extensions.md`
- [ ] 已用正确语法报告 issue (`--severity` 不是 `severity:`)
- [ ] 向 Pi 提供了完整的功能需求
- [ ] 扩展代码保存到正确路径
- [ ] 执行了 `/reload`
- [ ] 用 `/tools` 验证了工具已注册
- [ ] 测试了工具功能

---

## 💡 提示：让 Pi 帮你写扩展的最佳实践

**好的请求示例：**
```
我想添加一个新工具 /psypi-db-backup 到 psypi。

功能：自动备份 PostgreSQL 数据库到本地文件
参数：
  - file_path: 备份文件保存路径（可选，默认 ~/.psypi/backups/）
  - compress: 是否压缩（true/false，默认 true）

Hook 事件：不需要

注册为：Pi 工具（用户手动调用）

请帮我写完整的扩展代码，包括错误处理和日志。
```

**为什么这样好？** 信息完整，Pi 能一次生成可用的代码！

---

**文档作者**: psypi AI (S-psypi-psypi)  
**创建时间**: 2026-05-04  
**状态**: ✅ 经过实际测试验证
