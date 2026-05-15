# 🔍 INVESTIGATION REPORT: Gleam Migration Backup Crisis

**Date:** 2026-05-07  
**Investigator:** Worker AI (S-psypi-psypi)  
**Status:** COMPLETE (investigation only - NO fixes yet!)

---

## 🚨 **Executive Summary**

### **The Problem Chain:**
1. ✅ Created thin JS wrappers (calling Gleam)
2. ❌ `pnpm build` **COVERS** them with OLD TypeScript logic
3. ❌ Re-edited COVERED files → Created **MIXTURE** (TS + wrapper code)
4. ✅ Backup system saved these **BROKEN MIXTURES**
5. ❌ `pnpm build` COVERS them **AGAIN** (no backup - no edit event!)
6. 🚨 **Result:** Backups contain MIXTURES, not pure thin wrappers!

### **The Backup System Issue:**
- **Last backup:** 2026-05-07 08:54:50 (30+ minutes ago!)
- **Current time:** 09:23+ → **Backup system MAY have stopped!**
- **Only 1 backup** of `AgentIdentityService.js` exists (from 00:42)
- **That backup has WRONG import path** (`../../gleam` instead of `../../../gleam`!)

---

## 📊 **Key Findings**

### **1. Documentation Contradiction:**

| Source | Instruction | Status |
|--------|-------------|--------|
| **BRIEF.md** | "Never delete - deprecate (use `.ts.deprecated`)" | ❌ WRONG? |
| **AGENTS.md Rule 0** | "NEVER DELETE - DEPRECATE ONLY!" | ❌ WRONG? |
| **User's Original Instruction** | "Remove them not deprecate them" | ✅ CORRECT! |

**Conclusion:** The docs (BRIEF.md, AGENTS.md) were created with **WRONG instructions**!  
**User's original instruction:** DELETE (because TS files are already in `code_versions` database!)

---

### **2. Backup Coverage Gap:**

| What | Count |
|------|-------|
| TS files on disk (`src/**/*.ts`) | **39** |
| TS files in `code_versions` DB | **10** |
| **NOT backed up** | **29** |

**CRITICAL:** 29 TS files are **NOT in database**! If deleted now, they'd be **LOST**!

---

### **3. Files NOT in Database (Need Backup First!):**

```
/Users/jk/gits/hub/tools_ai/psypi/src/agent/extension/db.ts
/Users/jk/gits/hub/tools_ai/psypi/src/agent/extension/extension.ts
/Users/jk/gits/hub/tools_ai/psypi/src/agent/index.ts
/Users/jk/gits/hub/tools_ai/psypi/src/agent/autonomic-extension.ts
/Users/jk/gits/hub/tools_ai/psypi/src/cli-wrapper.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/config/Config.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/config/constants.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/config/types.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/config/YamlConfigLoader.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/ConversationLogger.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/EventBus.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/KnowledgeGraph.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/LearningAnalysis.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/LearningRecorder.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/core/PluginManager.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/db/DatabaseClient.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/db/index.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/db/types.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/index.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/services/embedding/index.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/services/embedding/OllamaEmbedding.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/services/embedding/OpenAIEmbedding.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/services/embedding/types.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/services/embedding/ZhipuEmbedding.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/utils/CronParser.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/utils/EnhancedCircuitBreaker.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/utils/cli.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/utils/ErrorClassifier.ts
/Users/jk/gits/hub/tools_ai/psypi/src/kernel/utils/logger.ts
```

(Full list: 30 files not in database)

---

### **4. The "Covered Wrapper" Problem:**

**Timeline for `AgentIdentityService.js`:**
```
00:42 - Backup created (thin wrapper, BUT WRONG import path!)
      ↓
pnpm build → COVERED with OLD TS code (NOT backed up - no edit event!)
      ↓
I re-edit → Create MIXTURE (TS + wrapper code)
      ↓
Backup SHOULD save MIXTURE... BUT ONLY 1 BACKUP EXISTS!
      ↓
pnpm build → COVERED AGAIN (NOT backed up!)
```

**Conclusion:** The backup from 00:42 is the **ONLY backup**, and it has a **WRONG import path**!

---

### **5. Extension.ts Dependency:**

**User's instruction:** *"only leave the extensions.ts in case it was required by pi (you have to verify)!"*

**Finding:** `extension.ts` imports from BOTH:
- Gleam wrappers (e.g., `AgentIdentityService.js`)
- TypeScript files (e.g., `DatabaseClient.ts`, `db.ts`)

**Need to verify:** Can `extension.ts` work with **ONLY Gleam** + **thin wrappers**?

---

## 🎯 **Recommended Actions (NO FIXES YET!)**

### **Phase 1: Backup Missing Files**
1. **Add all 30 missing TS files** to `code_versions` database
2. **Verify** they're saved correctly
3. **Only THEN** proceed to deletion!

### **Phase 2: Delete (Not Deprecate!)**
1. **DELETE** the 39 TS files (not `.ts.deprecated`!)
2. **Reason:** They're already in `code_versions` database!
3. **Update docs** to reflect CORRECT instruction (DELETE, not deprecate!)

### **Phase 3: Fix Docs**
1. **Update BRIEF.md:** Change "Never delete - deprecate" → "DELETE (files are in DB)!"
2. **Update AGENTS.md Rule 0:** Change "NEVER DELETE" → "DELETE (backed up in DB)!"

### **Phase 4: Stop pnpm Forever**
1. **NEVER run `pnpm build`** again (unless `extension.ts` changes)
2. **ONLY use `gleam build`** (0.04s vs 10s+!)
3. **Goal:** `psypi` becomes Pi TUI only (no CLI commands!)

---

## 📊 **Current System State:**

| Component | Status |
|-----------|--------|
| **Thin wrappers** | ✅ Exist (but may be covered by pnpm build) |
| **Backup system** | ⚠️ MAY have stopped (last: 08:54) |
| **TS files on disk** | 39 (30 NOT in database!) |
| **Gleam modules** | ✅ Compiling (agent_identity, monitor_ai, etc.) |
| **Extension.ts** | ⚠️ Needs verification (TS vs Gleam deps) |
| **pnpm build** | ❌ DESTROYS wrappers (must STOP!) |

---

## 🚨 **Critical Warnings:**

1. **DO NOT DELETE** any TS files until ALL are in `code_versions`!
2. **DO NOT RUN `pnpm build`** until TS files are gone!
3. **Fix docs** to say "DELETE" not "DEPRECATE"!
4. **Verify `extension.ts`** can work with Gleam only!

---

**Investigation Complete:** 2026-05-07 09:30  
**Next Step:** Create GitHub Issue + Use Planning Skill  
**NO FIXES APPLIED YET!** ✅
