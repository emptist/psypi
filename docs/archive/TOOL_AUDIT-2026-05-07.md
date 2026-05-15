# Tool & Command Audit - 2026-05-07

**Auditor:** S-psypi-psypi  
**Purpose:** Audit Pi tools vs old CLI commands, find missing/unregistered tools

---

## Summary Numbers

| Category | Count | Notes |
|----------|-------|-------|
| **Registered Pi Tools** | 25 | Actually in `extension.js` |
| **Old CLI Commands** | 34 | From `cli-vs-pi-tools.md` |
| **CLI→Pi Tools** | 33 | All except `provider-set-key`, `help` |
| **Missing from Registration** | 11+ | Tools shifted but not registered |
| **Deleted CLI (no Pi tool)** | 10+ | Commands deleted before Pi tool shift |

---

## 1. Registered Pi Tools (25)

```
psypi-areflect
psypi-broadcast-list
psypi-broadcast-send
psypi-inter-review-request
psypi-inter-review-show
psypi-inter-reviews
psypi-issue-add
psypi-issue-list
psypi-issue-resolve
psypi-learn
psypi-meeting-add-opinion
psypi-meeting-complete
psypi-meeting-create
psypi-meeting-get
psypi-meeting-list-opinions
psypi-meeting-list
psypi-my-id
psypi-partner-id
psypi-skill-build
psypi-skill-list
psypi-skill-search
psypi-skill-show
psypi-system-health
psypi-system-housekeeping
psypi-task-add
```

**Missing from registration (mentioned in cli-vs-pi-tools.md):**
- ❌ `psypi-task-complete` (exists in Gleam `task.gleam`)
- ❌ `psypi-tools` (mentioned in doc)
- ❌ `psypi-agents` (mentioned in doc)
- ❌ `psypi-validate-commit` (mentioned in doc)
- ❌ `psypi-doc-restore` (Pi tool without CLI)
- ❌ `psypi-doc-query` (exists in Gleam?)
- ❌ `psypi-announce` (mentioned in doc)

---

## 2. Deleted CLI Commands (No Pi Tool)

Deleted CLI command files (from git log):
```
src/kernel/cli/BroadcastCommands.ts      → ✅ Has Pi tools (broadcast-*)
src/kernel/cli/InterReviewCommands.ts    → ✅ Has Pi tools (inter-review-*)
src/kernel/cli/IssueCommands.ts         → ✅ Has Pi tools (issue-*)
src/kernel/cli/MeetingCommands.ts        → ✅ Has Pi tools (meeting-*)
src/kernel/cli/MonitoringCommands.ts     → ⚠️ Has psypi-system-* (renamed)
src/kernel/cli/ReviewCommands.ts        → ❌ NO Pi tool (psypi-commit uses fake)
src/kernel/cli/SkillBuilderCommands.ts   → ✅ Has Pi tools (skill-*)
src/kernel/cli/SkillCommands.ts         → ✅ Has Pi tools (skill-*)
src/kernel/cli/TaskCommands.ts          → ⚠️ Missing psypi-task-complete
```

**Commands deleted WITHOUT Pi tool replacement:**
1. ❌ `psypi-autonomic-review` (was in MonitoringCommands.ts) → No Pi tool!
2. ❌ `psypi-autonomic-set-model` → No Pi tool!
3. ❌ `psypi-autonomic-model` → No Pi tool!
4. ❌ `psypi-review` (from ReviewCommands.ts) → No Pi tool!
5. ❌ `psypi-validate-commit` → Not registered!

---

## 3. Unregistered Pi Tools (Shifted but not Registered)

Gleam modules with tool functions NOT in `extension.js`:

| Gleam Module | Function | Should be Tool? |
|--------------|----------|------------------|
| `task.gleam` | `complete()` | ✅ `psypi-task-complete` |
| `agents.gleam` | `list()` | ✅ `psypi-agents` |
| `doc.gleam` | `restore()` | ✅ `psypi-doc-restore` |
| `doc.gleam` | `query()` | ✅ `psypi-doc-query` |
| `validate.gleam` | `commit()` | ✅ `psypi-validate-commit` |
| `announce.gleam` | `send()` | ✅ `psypi-announce` |
| `tools.gleam` | `list()` | ✅ `psypi-tools` |

---

## 4. Current Status

### Working (Registered & Functional)
- ✅ Identity tools (my-id, partner-id)
- ✅ Task tools (task-add, but NOT task-complete!)
- ✅ Skill tools (list, build, show, search)
- ✅ Issue tools (add, list, resolve)
- ✅ Meeting tools (all 6)
- ✅ Broadcast tools (send, list)
- ✅ Inter-review tools (request, list, show)
- ✅ System tools (health, housekeeping)
- ✅ Learning tools (learn, but areflect has no impl)

### Missing/Broken
- ❌ `psypi-task-complete` (NOT registered!)
- ❌ `psypi-commit` (uses fake Monitor AI)
- ❌ `psypi-autonomic-review` (deleted CLI, no Pi tool)
- ❌ `psypi-tools` (not registered)
- ❌ `psypi-agents` (not registered)
- ❌ `psypi-validate-commit` (not registered)

---

## 5. Recommendations

### Immediate (Task 2 Completion)
1. ✅ Register `psypi-task-complete` (exists in Gleam)
2. ✅ Register `psypi-tools` (list all tools)
3. ✅ Register `psypi-agents` (list all AIs)
4. ⚠️ Create `psypi-commit` real tool (call inter-review)

### Future (After Gleam Migration)
1. 📋 Implement `psypi-autonomic-review` (system review tool)
2. 📋 Implement `psypi-validate-commit` (commit validation)
3. 📋 Rewrite Monitor AI as full Pi agent ("God in the sky")

---

**Conclusion:**  
- 25 Pi tools registered, but 11+ more exist but unregistered  
- 34 old CLI commands, most shifted but some deleted without replacement  
- System is functional but incomplete  
- AIs deleted too aggressively (39 TS files deleted in Phase 07-09)  

**Next:** Register missing tools to complete Task 2!
