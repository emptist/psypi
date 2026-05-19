# Psypi Deep Code Review — 2026-05-01

> Deep codebase analysis focusing on hardcoded strings, SQL safety, type safety, and architectural issues

---

## CRITICAL

### C1. SQL Injection in DatabaseClient.ts:40
**File:** `src/kernel/db/DatabaseClient.ts`
**Line:** 40
```typescript
await client.query(`SET app.git_branch = '${branch}'`);
```
`branch` comes from `execSync('git rev-parse --abbrev-ref HEAD')`. A git branch name like `'; DROP TABLE issues; --` would execute arbitrary SQL. Must use parameterized query or sanitize.

### C2. Hardcoded DB Password in Source Code
**File:** `src/kernel/index.ts`
**Line:** 31
```typescript
password: process.env.DB_PASSWORD || 'postgres',
```
Default password 'postgres' hardcoded in source. Should fail if no password configured, not fall back to a known default.

---

## HIGH

### H1. Hardcoded 'psypi' as created_by (9 locations)
**File:** `src/kernel/index.ts`
**Lines:** 59, 90, 282, 299, 312, 334, 344, 362, 369
All INSERT statements and fallbacks use hardcoded `'psypi'` instead of resolved agent identity from `AgentIdentityService`. This causes incorrect attribution in the database.

### H2. Hardcoded 'nupi' as created_by (3 locations)
**File:** `src/agent/extension/extension.ts`
**Lines:** 423, 1054, 1066
Meeting opinions, tasks, and issues created with `'nupi'` hardcoded. Should use `AgentIdentityService.getResolvedIdentity()`.

### H3. Duplicate DB Connection Configuration (3 paths)
**Files:**
- `src/kernel/index.ts:26-32` — creates `new Pool()` with hardcoded defaults
- `src/agent/extension/db.ts:16-28` — creates `new Pool()` with NUPI_DB_* env vars
- `src/kernel/config/Config.ts` — proper centralized config (unused by above)

Three separate DB config paths for the same database. `kernel/index.ts` and `agent/extension/db.ts` bypass the centralized `Config` class entirely.

### H4. Dynamic SQL with Template Literals in Memory.ts
**File:** `src/kernel/core/Memory.ts`
**Lines:** 382, 429
```typescript
`DELETE FROM ${tableName} WHERE updated_at < $1`
`DELETE FROM ${tableName} WHERE id = ANY($1)`
```
While `tableName` comes from `DATABASE_TABLES` constant (not user input), this pattern is fragile and should use a whitelist or at minimum validate against known table names.

### H5. Dynamic SQL Column Building in cli.ts
**File:** `src/cli.ts`
**Lines:** 271-293
```typescript
updates.push(`encrypted_key = $${idx++}`);
// ...
`UPDATE provider_api_keys SET ${updates.join(', ')} WHERE provider = $${idx}`
```
Column names are built dynamically. While values are parameterized, the column name list is hardcoded and safe, but the pattern is error-prone.

### H6. `as any` Type Bypasses (10 instances)
**Files:**
- `src/kernel/index.ts:398,424` — `this.pool as any` for InterReviewService and BroadcastService
- `src/agent/extension/extension.ts:1122,1124,1128,1214` — `(pi as any).on()`, `(m as any)`, `(event.message as any).timestamp`
- `src/kernel/cli/index.ts:387,407` — `args[posIdx + 1] as any`, `args[priorityIndex + 1] as any`
- `src/kernel/services/PiSDKExecutor.ts:42` — `} as any)`

These bypass TypeScript's type system entirely. The comment on line 397 says "Use 'as any' to bypass type checking (focus on functionality)" — this is a tech debt time bomb.

### H7. Empty File: agent/index.ts
**File:** `src/agent/index.ts`
Zero lines. Dead file that should be removed or properly implemented.

### H8. Swallowed Exception in extension.ts
**File:** `src/agent/extension/extension.ts`
**Line:** 963
```typescript
try { mkdirSync(dir, { recursive: true }); } catch {}
```
Silently ignores all errors including permission denied, disk full, etc.

---

## MEDIUM

### M1. DB_NAME Defaults to 'nezha' Instead of 'psypi'
**Files:**
- `src/kernel/index.ts:29` — `process.env.DB_NAME || 'nezha'`
- `src/agent/extension/db.ts:18` — `process.env.NUPI_DB_NAME || "nezha"`
- `src/kernel/config/Config.ts:141` — `database || 'nezha'`

Since psypi is its own project, the default database name should be 'psypi', not 'nezha'.

### M2. Inconsistent Environment Variable Naming
**kernel/index.ts** uses: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
**agent/extension/db.ts** uses: `NUPI_DB_HOST`, `NUPI_DB_USER`, `NUPI_DB_NAME`, `NUPI_DB_PORT`
**kernel/config/constants.ts** uses: `NEZHA_DB_HOST`, `NEZHA_DB_PORT`, etc.

Three different env var prefixes for the same database. Should be unified to `PSYPI_DB_*`.

### M3. Inconsistent .env Loading Paths
**cli.ts** loads from:
- `~/.config/psypi/.env`
- `~/.psypi/.env`

**kernel/cli/index.ts** loads from:
- `~/.config/nezha/.env`
- `~/.nezha/.env`

Two different config locations for the same project. Users must maintain both.

### M4. 45 Instances of `any` Type
**Distribution:**
- `src/agent/extension/extension.ts` — 15 instances (params, settings, event objects)
- `src/agent/extension/db.ts` — 3 instances (params arrays)
- `src/kernel/index.ts` — 6 instances (service references, params arrays)
- `src/kernel/services/ai/FallbackProvider.ts` — 3 instances (db, constructor, error)
- `src/kernel/cli/index.ts` — 6 instances (task/issue/learning row types)
- `src/kernel/db/types.ts` — 1 instance (config: any)

Weak type safety throughout the codebase.

### M5. console.log/error in Non-CLI Code
**Files:**
- `src/kernel/index.ts:435` — `console.error('Announce error:', err)`
- `src/kernel/core/ConversationLogger.ts:200,211,219` — `console.error(...)`

Should use the existing `logger` utility for consistent logging.

### M6. Kernel.getContext() Uses 'psypi' Fallback
**File:** `src/kernel/index.ts`
**Line:** 344
```typescript
const agentType = process.env.AGENT_TYPE || 'psypi';
```
Should use `AgentIdentityService.getResolvedIdentity()` instead of hardcoded fallback.

### M7. Kernel.startSession() Defaults to 'psypi'
**File:** `src/kernel/index.ts`
**Line:** 369
```typescript
async startSession(agentType: string = 'psypi') {
```
Should resolve from AgentIdentityService.

### M8. MeetingCommands.ts Hardcodes 'nezha' as Author
**File:** `src/kernel/cli/MeetingCommands.ts`
**Line:** 80
```typescript
map.set(id, 'nezha');
```
Should use resolved agent identity.

### M9. TraeSkillSyncService Defaults to 'nezha'
**File:** `src/kernel/services/TraeSkillSyncService.ts`
**Line:** 108
```typescript
`- **Source**: ${skill.source || 'nezha'}`
```
Should default to 'psypi'.

### M10. ClawHubClient Tags 'nezha'
**File:** `src/kernel/services/ClawHubClient.ts`
**Line:** 115
```typescript
tags: ['helper', 'utilities', 'nezha']
```
Should tag as 'psypi'.

---

## LOW

### L1. AgentIdentityService.detectSource() Returns 'nezha'
**File:** `src/kernel/services/AgentIdentityService.ts`
**Line:** 137
```typescript
return 'nezha';
```
Default source detection returns 'nezha'. Should return 'psypi' when running in psypi context.

### L2. Multiple DatabaseClient Instantiations (7 pools)
**Locations:**
- `src/kernel/index.ts:26` — `new Pool()`
- `src/agent/extension/db.ts:28` — `new Pool()`
- `src/kernel/cli/index.ts:105` — `new DatabaseClient(config)`
- `src/kernel/cli/skill-import.ts:164` — `new DatabaseClient(config)`
- `src/kernel/cli/InterReviewCommands.ts:11` — `new DatabaseClient(config)`
- `src/kernel/services/DailyMemory.ts:327` — `new DatabaseClient(Config.getInstance())`
- `src/kernel/services/AgentIdentityService.ts:57` — `new DatabaseClient(Config.getInstance())`

Each creates its own connection pool. Should use a shared singleton or dependency injection.

### L3. NEZHA_SECRET Used as Encryption Key Name
**Files:** Multiple (ApiKeyService, EncryptionService, TaskEncryptionService, JwtService)
The encryption secret env var is still called `NEZHA_SECRET`. Should be `PSYPI_SECRET` or at least accept both for backward compatibility.

---

## Summary

| Severity | Count | Key Theme |
|----------|-------|-----------|
| Critical | 2 | SQL injection, hardcoded password |
| High | 8 | Hardcoded identity, duplicate config, type bypasses |
| Medium | 10 | 'nezha' residue, inconsistent naming, weak types |
| Low | 3 | Source detection, pool proliferation, env var naming |

**Top Priority Actions:**
1. Fix SQL injection in DatabaseClient.ts:40 (parameterize the SET command)
2. Remove hardcoded 'postgres' password default
3. Replace all hardcoded 'psypi'/'nupi' created_by with AgentIdentityService
4. Unify DB connection config through Config class
5. Replace `as any` with proper types in Kernel and extension
