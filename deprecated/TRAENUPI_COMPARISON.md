# TraeNuPI vs Psypi: Missing Functions Comparison

Generated: 2026-05-01

## Executive Summary

TraeNuPI has several convenience functions that psypi lacks or implements differently. This document identifies gaps to help guide migration or feature parity.

---

## 1. ID Resolution (Critical Difference)

### TraeNuPI: Short IDs Supported ✅

```typescript
// traenupi/src/common/resolve-id.ts
resolveIssueId("61b48b92")  // Returns full UUID
resolveMeetingId("abc123")   // Returns full UUID
```

**All commands accept short IDs:**
- `traenupi issue-resolve 61b48b92` → Works
- `traenupi meeting show abc123` → Works

### Psypi: Short IDs NOT Supported in Some Commands ❌

```typescript
// psypi/src/kernel/utils/resolve-id.ts EXISTS but...
// psypi/src/cli.ts line 135:
const success = await kernel.resolveIssue(issueId, options.notes);
// Does NOT call resolveIssueId()!
```

**Problem:**
- `psypi issue-resolve 61b48b92` → Fails (expects full UUID)
- `psypi issue-resolve 61b48b92-a902-4ba9-8321-dc423635f108` → Works

**Root Cause:**
- `resolveIssueId()` exists in `src/kernel/utils/resolve-id.ts`
- But `src/cli.ts` doesn't use it for `issue-resolve` command
- Only `resolveMeetingId()` is used (for meeting commands)

**Fix Required:**
```typescript
// In src/cli.ts, change:
const success = await kernel.resolveIssue(issueId, options.notes);

// To:
import { resolveIssueId } from './kernel/utils/resolve-id.js';
const resolvedId = await resolveIssueId(DatabaseClient.getInstance(), issueId);
const success = await kernel.resolveIssue(resolvedId || issueId, options.notes);
```

---

## 2. Missing TraeNuPI Features in Psypi

### 2.1 Baby AI / askPi Function

**TraeNuPI has:**
```typescript
// traenupi/src/trae/baby-ai.ts
export function askPi(question: string, history: ConversationItem[], quick: boolean, useSession: boolean): string
export function tellmeSync(question: string, quick: boolean, useSession: boolean): void
```

**Psypi:**
- ❌ No `askPi` function
- ❌ No `tellme` command
- ❌ No baby AI concept

**Impact:** TraeNuPI can ask its "baby AI" for context. Psypi cannot.

---

### 2.2 Project Initialization

**TraeNuPI has:**
```typescript
// traenupi/src/trae/init.ts
export function initProject(projectPath?: string): void
```

Creates:
- `.trae/rules/project_rules.md`
- `.trae/skills/keep-alive/SKILL.md`
- `.trae/skills/traenupi-awakener/SKILL.md`
- `.trae/skills/session-survival/SKILL.md`

**Psypi:**
- ❌ No `init` command
- ❌ No project scaffolding

**Impact:** TraeNuPI can initialize Trae projects. Psypi cannot.

---

### 2.3 Local Storage Utilities

**TraeNuPI has:**
```typescript
// traenupi/src/common/storage.ts
export function loadHistory(): ConversationItem[]
export function saveHistory(history: ConversationItem[]): void
export function loadReminders(): Reminder[]
export function saveReminders(reminders: Reminder[]): void
export function loadBookmarks(): Bookmark[]
export function saveBookmarks(bookmarks: Bookmark[]): void
export function loadMoodHistory(): MoodEntry[]
export function saveMoodHistory(moodHistory: MoodEntry[]): void
export function loadState(): Record<string, unknown>
export function saveState(state: Record<string, unknown>): void
```

**Psypi:**
- ❌ No local storage utilities
- ❌ No history tracking
- ❌ No reminders
- ❌ No bookmarks
- ❌ No mood tracking

**Impact:** TraeNuPI has persistent local state. Psypi relies only on database.

---

### 2.4 Knowledge Utilities

**TraeNuPI has:**
```typescript
// traenupi/src/common/knowledge.ts
export function loadKnowledge(): KnowledgeEntry[]
export function addKnowledge(key: string, value: string, category: string): void
export function getKnowledgeByCategory(category: string): KnowledgeEntry[]
export function searchKnowledge(term: string): KnowledgeEntry[]
export function getRecentKnowledge(limit: number): KnowledgeEntry[]
```

**Psypi:**
- ✅ Has `MemoryService` for database storage
- ❌ No local file fallback
- ❌ No `searchKnowledge` convenience function

**Impact:** TraeNuPI can work offline with local files. Psypi requires database.

---

### 2.5 Meeting Utilities

**TraeNuPI has:**
```typescript
// traenupi/src/common/meeting.ts
export function getMeetingInfo(meetingId: string): Meeting | null
export function getActiveMeetings(): Meeting[]
export function getMeetingOpinions(meetingId: string): MeetingOpinion[]
export function addOpinion(meetingId: string, author: string, message: string): boolean
export function createMeeting(topic: string, author: string): string | null
export function closeMeeting(meetingId: string): boolean
export function getMeetingStats(): { total: number; active: number; opinions: number }
```

**Psypi:**
- ✅ Has `MeetingCommands` and `MeetingDbCommands`
- ❌ No simple function exports
- ❌ Must instantiate classes to use

**Impact:** TraeNuPI provides simple function API. Psypi requires class instantiation.

---

### 2.6 Daemon / Presence System

**TraeNuPI has:**
```typescript
// traenupi/src/trae/daemon.ts
export function startDaemon(): void
export function stopDaemon(): void

// traenupi/src/trae/presence.ts
export function updatePresence(): void
export function getPresence(): PresenceInfo
```

**Psypi:**
- ❌ No daemon system
- ❌ No presence tracking

**Impact:** TraeNuPI can run as background daemon. Psypi is CLI-only.

---

### 2.7 Trae-Specific Features

**TraeNuPI has:**
```typescript
// traenupi/src/trae/bookmarks.ts
export function addBookmark(name: string, path: string): void
export function listBookmarks(): Bookmark[]
export function removeBookmark(name: string): void

// traenupi/src/trae/reminders.ts
export function addReminder(message: string, when: Date): void
export function checkReminders(): Reminder[]
export function dismissReminder(id: string): void

// traenupi/src/trae/mood.ts
export function recordMood(mood: string, note?: string): void
export function getMoodHistory(): MoodEntry[]
```

**Psypi:**
- ❌ No bookmarks
- ❌ No reminders
- ❌ No mood tracking

**Impact:** TraeNuPI has Trae-specific features. Psypi is generic.

---

## 3. Database Access Differences

### TraeNuPI: Two Modes

```typescript
// traenupi/src/common/db.ts - psql shell (sync)
export function psqlQuery(sql: string, options?: DbQueryOptions): string

// traenupi/src/common/db-safe.ts - pg pool (async)
export async function querySafe<T>(sql: string, params: any[]): Promise<T[]>
```

**Note:** `psqlQuery` is deprecated due to SQL injection risk.

### Psypi: Single Mode

```typescript
// psypi/src/kernel/db/DatabaseClient.ts
async query<T>(sql: string, params?: unknown[]): Promise<QueryResult<T>>
```

**Difference:**
- TraeNuPI has both sync (psql) and async (pg) modes
- Psypi is async-only
- TraeNuPI's sync mode is useful for CLI scripts

---

## 4. Entity Types Supported

### TraeNuPI resolve-id.ts
```typescript
export type EntityType =
  | "meeting"
  | "task"
  | "issue"
  | "agent"
  | "opinion"
  | "skill"
  | "memory"
  | "inter_review";  // ✅ Has inter_review
```

### Psypi resolve-id.ts
```typescript
export type EntityType =
  | 'meeting'
  | 'task'
  | 'issue'
  | 'agent'
  | 'opinion'
  | 'skill'
  | 'memory';
  // ❌ Missing inter_review
```

**Impact:** Psypi cannot resolve inter_review IDs.

---

## 5. Summary Table

| Feature | TraeNuPI | Psypi | Migration Needed |
|---------|----------|-------|------------------|
| Short ID resolution (issues) | ✅ | ❌ | **Critical** |
| Short ID resolution (meetings) | ✅ | ✅ | Done |
| Short ID resolution (inter_review) | ✅ | ❌ | Add type |
| Baby AI / askPi | ✅ | ❌ | Optional |
| Project init | ✅ | ❌ | Optional |
| Local storage | ✅ | ❌ | Optional |
| Knowledge utilities | ✅ | Partial | Add search |
| Meeting utilities | ✅ (functions) | ✅ (classes) | Style diff |
| Daemon system | ✅ | ❌ | Optional |
| Bookmarks | ✅ | ❌ | Trae-specific |
| Reminders | ✅ | ❌ | Trae-specific |
| Mood tracking | ✅ | ❌ | Trae-specific |
| Sync DB access | ✅ (deprecated) | ❌ | Not needed |

---

## 6. Recommended Actions

### Critical (Must Fix)

1. **Add short ID resolution to issue-resolve command**
   - File: `src/cli.ts`
   - Import `resolveIssueId` from `./kernel/utils/resolve-id.js`
   - Use it before calling `kernel.resolveIssue()`

2. **Add `inter_review` to EntityType in psypi**
   - File: `src/kernel/utils/resolve-id.ts`
   - Add `inter_review: { table: 'inter_reviews', idColumn: 'id' }`

### Important (Should Have)

3. **Add resolve functions for all entity types in CLI**
   - `issue-add` should accept short ID for related entities
   - `task-update` should accept short ID

### Optional (Nice to Have)

4. **Add local storage utilities** - For offline capability
5. **Add knowledge search** - Convenience function
6. **Add daemon system** - Background operation

---

## 7. Code Examples

### Fix for issue-resolve (Critical)

```typescript
// src/cli.ts - line 130-137
program
  .command('issue-resolve <issueId>')
  .description('Mark an issue as resolved')
  .option('--notes <text>', 'Resolution notes')
  .action(async (issueId, options) => {
    try {
      // ADD THIS:
      const resolvedId = await resolveIssueId(DatabaseClient.getInstance(), issueId);
      const success = await kernel.resolveIssue(resolvedId || issueId, options.notes);
      if (success) {
        console.log(`✅ Issue ${(resolvedId || issueId).slice(0,8)} marked as RESOLVED`);
      } else {
        console.log(`⚠️  Issue ${issueId.slice(0,8)} not found or already resolved`);
      }
    } catch (err) {
      console.error('Error:', err instanceof Error ? err.message : err);
    }
  });
```

### Add inter_review to EntityType

```typescript
// src/kernel/utils/resolve-id.ts - line 6-8
export type EntityType =
  | 'meeting'
  | 'task'
  | 'issue'
  | 'agent'
  | 'opinion'
  | 'skill'
  | 'memory'
  | 'inter_review';  // ADD THIS

// And in ENTITY_TABLES:
const ENTITY_TABLES: Record<EntityType, EntityTableConfig> = {
  // ... existing entries ...
  inter_review: { table: 'inter_reviews', idColumn: 'id' },  // ADD THIS
};
```

---

## Conclusion

The most critical gap is **short ID resolution for issues**. TraeNuPI users expect to use short IDs (8 characters) but psypi requires full UUIDs (36 characters).

The fix is simple: import and use the existing `resolveIssueId` function in the CLI commands.
