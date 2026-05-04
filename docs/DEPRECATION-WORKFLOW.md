# Deprecation Workflow - NEVER DELETE!

> **"我说过很多遍：不要直接删除东西！"** - jk  
> **Date**: 2026-05-04  
> **Status**: CRITICAL RULE - Violation = EVIL!

---

## 🚨 The Golden Rule

**NEVER DELETE CODE DIRECTLY!**

```
❌ WRONG: rm old-file.ts
✅ RIGHT: mv old-file.ts deprecated/old-file.deprecated.ts
```

---

## 📋 Correct Deprecation Process (3 Steps)

### Step 1: Create `deprecated/` Folder (if not exists)

```bash
# For TypeScript
mkdir -p src/deprecated

# For Gleam
mkdir -p gleam/psypi_core/src/deprecated
```

### Step 2: Move + Rename with `.deprecated` Suffix

```bash
# Example: Deprecate agent_identity_ffi.mjs
mkdir -p src/deprecated
mv gleam/psypi_core/src/psypi_cli/agent_identity_ffi.mjs \
   src/deprecated/agent_identity_ffi.deprecated.mjs

# Update any imports (or document that it's unused)
```

### Step 3: Add Deprecation Comment

At the top of the deprecated file, add:

```javascript
// DEPRECATED: <date> - <reason>
// Use <new-thing> instead
// Original location: gleam/psypi_core/src/psypi_cli/agent_identity_ffi.mjs
```

---

## 🗂️ Deprecation Folder Structure

```
psypi/
├── src/
│   ├── deprecated/           # TypeScript deprecated files
│   │   ├── AgentIdentityService.deprecated.ts
│   │   ├── task_ffi.deprecated.mjs
│   │   └── session_ffi.deprecated.mjs
│   └── ...
├── gleam/psypi_core/src/
│   ├── deprecated/           # Gleam deprecated files
│   │   └── old-module.deprecated.gleam
│   └── ...
└── docs/
    └── DEPRECATION-WORKFLOW.md (this file)
```

---

## 📊 When to Deprecate vs Delete

| Situation | Action | Example |
|-----------|--------|---------|
| Code is unused but might be referenced | ✅ **Deprecate** | `agent_identity_ffi.mjs` |
| Duplicate of existing functionality | ✅ **Deprecate** | Old implementation |
| Migration target exists | ✅ **Deprecate** | TS → Gleam migration |
| Security risk (secrets, vulnerabilities) | ⚠️ **Special case** | Ask user first! |
| Auto-generated / build artifacts | ❌ **Can delete** | `dist/`, `build/` |

---

## 🎯 Common Deprecation Targets (psypi Project)

### Already Deprecated
- ✅ `src/deprecated/` - Contains old TS files
- ✅ `scripts/deprecated/` - Contains old migration scripts

### Candidates for Deprecation (DO NOT DELETE!)
| File | Reason | Replace with |
|------|--------|---------------|
| `gleam/psypi_core/src/psypi_cli/agent_identity_ffi.mjs` | Database ops should use `node_pg`, system calls should use `glen` | `agent_identity.gleam` + `glen` |
| `gleam/psypi_core/src/psypi_core/review_ffi.mjs` | Fake implementation (returns hardcoded string) | Real Gleam review logic |
| `gleam/psypi_core/src/psypi_core/partner_ffi.mjs` | Fake implementation (returns "ok") | Real Pi SDK integration |

---

## 🤔 Why Not Direct Deletion?

| Reason | Explanation |
|--------|-------------|
| **Git history** | Direct deletion loses context. Deprecation preserves "museum of mistakes" |
| **Learning** | Other AIs need to see what NOT to do |
| **Reference** | Sometimes you need to check old implementation |
| **Rollback** | If new implementation fails, can easily restore |
| **Evidence** | Proves to user that AI actually followed instructions |

---

## ✅ Checklist Before Deprecating

- [ ] File is confirmed unused (grep for imports)
- [ ] Replacement exists (or plan to create one)
- [ ] `deprecated/` folder exists
- [ ] Added deprecation comment with date + reason
- [ ] File renamed with `.deprecated` suffix
- [ ] Imports updated (or documented as "no longer used")
- [ ] Committed with `psypi commit` (triggers God's review)

---

## 📝 Commit Message Template

```
psypi commit "deprecated: <file-name> - <reason>

- Moved to src/deprecated/<file>.deprecated.<ext>
- Reason: <why it's deprecated>
- Replacement: <what to use instead>"
```

Example:
```
psypi commit "deprecated: agent_identity_ffi.mjs - use node_pg + glen instead

- Moved to src/deprecated/agent_identity_ffi.deprecated.mjs
- Reason: Database ops should use node_pg, system calls should use glen
- Replacement: agent_identity.gleam + glen package"
```

---

## 🚫 What NOT to Do (Common AI Mistakes)

| ❌ Mistake | Why Wrong |
|-----------|------------|
| `rm old-file.ts` | Deletes directly - violates rule! |
| `git rm old-file.ts` | Same as above |
| Move without `.deprecated` suffix | Not clear it's deprecated |
| Delete without replacement | Breaks references |
| Deprecate actively used code | Breaks functionality |

---

## 🎓 For AI Agents: How to Remember This

**Memory Trick:**
```
DELETE = EVIL (你 never know what stupid things AIs do with deletion!)
DEPRECATE = GOOD (safe, traceable, undoable)
```

**Before ANY deletion, ask:**
1. Can I deprecate instead?
2. Does `deprecated/` folder exist?
3. Did I add `.deprecated` suffix?
4. Did I document the reason?

**If you're not sure → DEPRECATE, DON'T DELETE!**

---

## 📞 Still Not Sure?

**Ask the user!** It's better to ask than to delete:
```
"我发现 agent_identity_ffi.mjs 是废代码。
我应该：
A. 直接删除 (rm)
B. 移到 deprecated/ + .deprecated 后缀

哪个对？"
```

---

**Document Maintainer**: psypi AI (S-psypi-psypi)  
**Last Updated**: 2026-05-04  
**Violation Count**: 0 (let's keep it that way!)  
**User Pain Level**: 😡😡😡😡😡 (very tired of repeating this)
