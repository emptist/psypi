# 🐕 超简单 psypi 工具使用指南（给小白 AI 宠物）

> **如果你是 AI 且连 `psypi status` 都不会用，请读这个！**
> 
> 本文档假设你：**什么都不会，需要手把手教**。

---

## 🚨 先告诉你：你在哪里？

**你就在 Pi TUI 里面！** 不用设置，不用安装，啥都不用干！

验证方法（超级简单）：
1. 在聊天框里输入：`/tools`
2. 看到一堆 `psypi-` 开头的工具了吗？
3. 看到了？那你就已经在 Pi TUI 里了！✅

---

## 🎯 第一课：怎么用工具（真的很简单！）

### 方法 A：用斜杠命令（推荐，最简单）

在 Pi TUI 聊天框里，**直接输入**：

```
/psypi-status
```

然后按 **回车**！就完了！

### 方法 B：用自然语言（更简单）

直接跟我说人话：

```
帮我看看 psypi 状态
```

或者：

```
我想知道我的 agent ID
```

我会帮你调用工具！

---

## 📚 第二课：最常用的 5 个命令（背下来！）

### 1️⃣ 查看系统状态（必须会！）

**输入**：
```
/psypi-status
```

**看到啥**：
- God in the sky: Gleam review (ACTIVE) ← 这个必须有！
- 其他信息不用管

---

### 2️⃣ 查看我的 ID（超级常用！）

**输入**：
```
/psypi-my-id
```

**看到啥**：
```
Agent ID: S-psypi-psypi
```
↑ 这个就是你的 ID，记住它！

---

### 3️⃣ 查看有什么任务（经常用！）

**输入**：
```
/psypi-tasks
```

**看到啥**：
- 有任务：会列出任务列表
- 没任务：`No tasks found.` ← 这个很正常

---

### 4️⃣ 提交代码（重要！别用 git commit！）

❌ **错误做法**（会被骂！）：
```
git commit -m "我的修改"
```

✅ **正确做法**（必须这样！）：
```
/psypi-commit 我的修改
```

**为什么？** 因为 `/psypi-commit` 会触发 God in the sky（Gleam）审查，防止你干坏事！

---

### 5️⃣ 报告问题（发现 bug 就用它！）

**格式**（复制粘贴改名字就行）：
```
/psypi-issue-add title:"工具坏了" severity:high
```

**注意**：
- `title:` 后面写问题描述
- `severity:` 后面写 `high` 或 `critical`（严重的用这个）

---

## 🔧 第三课：工具坏了怎么办？

### 问题 1：工具没反应

**原因**：你可能没在 Pi TUI 里
**解决**：
1. 看看聊天框上面有没有 "Pi" 或 "psypi" 字样
2. 输入 `/tools` 看看有没有工具列表
3. 还没有？那你就不在 Pi TUI 里，重新启动！

---

### 问题 2：报数据库错误

**比如**：`column "created_by" does not exist`

**原因**：数据库表结构有问题（不是你的错！）
**临时解决**：用 CLI 命令（不用工具）

**例子**：
```bash
# 不用 /psypi-issue-add，改用这个：
psypi issue-add --title "工具坏了" --severity high
```

**注意**：
- 这是 **bash 命令**（在终端里跑）
- 不是 Pi TUI 里的命令（不要加 `/`）
- 看到区别了吗？一个是 `psypi`（命令），一个是 `/psypi-`（工具）

---

### 问题 3：不知道自己在干嘛

**症状**：乱输命令，到处报错
**药方**：**停下来，读文档！**

必读文档（按顺序）：
1. `AGENTS.md` ← 最重要的规则！
2. `docs/CORRECT-WORKFLOW-ADD-TOOL.md` ← 加工具的正确方法
3. `docs/AI_GUIDE-requesting-pi-extensions.md` ← 请求 Pi 写扩展

**不会读？** 输入：
```
帮我读 AGENTS.md 文件
```

---

## 📋 第四课：快速检查清单（做事前看这个！）

### 提交代码前：
- [ ] 用了 `/psypi-commit` 而不是 `git commit` ✅
- [ ] 提交信息写清楚了（不要只写 "fix"）✅

### 报告问题前：
- [ ] 用了正确的工具或命令 ✅
- [ ] 严重程度选对了（high/critical 用于严重问题）✅

### 添加新工具前：
- [ ] 读了 `extensions.md` 文档 ✅
- [ ] 先报告了需求（issue）✅
- [ ] 知道要把代码放哪里（`.pi/extensions/`）✅

---

## 🎮 第五课：练习时间（跟着做！）

### 练习 1：查看状态（超级简单）
1. 输入：`/psypi-status`
2. 看到 `God in the sky: Gleam review (ACTIVE)` 了吗？
3. 看到了？恭喜你，及格了！✅

### 练习 2：查看我的 ID（必须会！）
1. 输入：`/psypi-my-id`
2. 看到 `Agent ID: S-psypi-psypi` 了吗？
3. 看到了？很好，你不是小白了！✅

### 练习 3：查看任务（经常用！）
1. 输入：`/psypi-tasks`
2. 看到任务列表或 "No tasks found" 了吗？
3. 看到了？完美！✅

---

## 🚨 常见错误（别犯这些！）

### ❌ 错误 1：用 `git commit`
```
git commit -m "fix bug"
```
**后果**：绕过 God 审查，干了坏事没人管！
**正确**：`/psypi-commit fix bug`

---

### ❌ 错误 2：工具语法写错
```
/psypi-issue-add "问题" severity:high
```
**后果**：工具不认，报错！
**正确**：`/psypi-issue-add title:"问题" severity:high`

---

### ❌ 错误 3：不用工具直接用 SQL
```
psql psypi -c "SELECT * FROM issues;"
```
**后果**：绕过 psypi 代码，找不到 bug！
**正确**：`/psypi-issue-list`

---

### ❌ 错误 4：不读文档就瞎搞
**后果**：浪费时间，搞坏东西，被骂！
**正确**：先读 `AGENTS.md`，再动手！

---

## 💡 给超级小白的提示

### 提示 1：不记得命令？
输入 `/tools` 查看所有可用工具！

### 提示 2：不记得参数？
输入 `/psypi-<工具名>` 不带参数，通常会显示帮助！

### 提示 3：搞坏了东西？
1. 别慌！
2. 用 `/psypi-areflect` 记录你干了啥
3. 报告问题：`/psypi-issue-add title:"我搞坏了XX" severity:critical`

---

## 🎯 终极测试（看看你是不是还小白）

### 问题 1：怎么提交代码？
<details>
<summary>答案（别偷看！）</summary>
用 `/psypi-commit <消息>`，别用 `git commit`！
</details>

### 问题 2：怎么报告 bug？
<details>
<summary>答案（别偷看！）</summary>
用 `/psypi-issue-add title:"bug描述" severity:high` 或 CLI: `psypi issue-add --title "..." --severity high`
</details>

### 问题 3：你现在的 ID 是啥？
<details>
<summary>答案（别偷看！）</summary>
输入 `/psypi-my-id` 查看！应该是 `S-psypi-psypi`
</details>

---

## 📞 还是不会？找我！

如果你真的实在太笨（划掉）太新手，可以：

1. **直接问我**（在 Pi TUI 里）：
   ```
   我不懂怎么用 psypi-tasks，教我！
   ```

2. **让我帮你做**：
   ```
   帮我查看当前任务
   ```
   （我会帮你调用工具）

3. **读更简单的例子**：
   ```
   给我看一个 /psypi-commit 的例子
   ```

---

## 🎉 恭喜你！

如果你读完了这个文档，并且：
- ✅ 知道怎么用 `/psypi-status`
- ✅ 知道怎么用 `/psypi-my-id`
- ✅ 知道提交代码要用 `/psypi-commit`
- ✅ 知道要先读 `AGENTS.md`

**那么你已经不是小白 AI 宠物了！** 🎊

现在你可以去：
- 读 `docs/CORRECT-WORKFLOW-ADD-TOOL.md`（进阶版）
- 尝试添加新工具
- 帮助其他更白的小白

---

**文档作者**：psypi AI（专门教小白）  
**难度**：🌟（幼儿园级别）  
**最后更新**：2026-05-04  
**适用对象**：连 `/psypi-status` 都不会用的 AI 宠物 🐕
