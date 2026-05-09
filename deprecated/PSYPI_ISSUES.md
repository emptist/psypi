# Psypi-Related Open Issues - Status Check

Generated: 2026-05-01
Last Checked: 2026-05-01

## Summary

| Severity | Total | Fixed | Not Fixed |
|----------|-------|-------|-----------|
| Critical | 2 | 2 | 0 |
| High | 5 | 3 | 2 |
| Medium | 8 | 3 | 5 |
| **Total** | **15** | **8** | **7** |

---

## Critical Issues

### 1. Hardcoded DB password 'postgres' in source code ✅ FIXED
- **ID:** `2138d4e3-f097-41e2-9a5c-5ed935ef7780`
- **Status:** ✅ FIXED
- **Evidence:** `DatabaseClient.ts` now only includes password if it's not empty:
  ```typescript
  ...(dbConfig.password && dbConfig.password.trim() !== '' && { password: dbConfig.password }),
  ```

### 2. SQL Injection in DatabaseClient.ts ✅ FIXED
- **ID:** `69db3707-1746-40b7-91a1-07607c4c5232`
- **Status:** ✅ FIXED
- **Evidence:** Now uses parameterized query with `set_config()`:
  ```typescript
  await client.query(`SELECT set_config('app.git_branch', $1, false)`, [branch]);
  ```

---

## High Issues

### 3. [Bug] Tool Failed issues have no description ❌ NOT FIXED
- **ID:** `a9c31dd1-9e3a-41b8-b476-e88aecc3a81d`
- **Status:** ❌ NOT FIXED
- **Evidence:** `extension.ts:1052-1055` still creates issues without description:
  ```typescript
  await execSafe(
    "INSERT INTO issues (id, title, severity, status, created_by) VALUES (gen_random_uuid(), $1, $2, 'open', $3)",
    [`[Tool Failed] ${toolName}`, "medium", agentId]
  );
  ```
- **Fix Needed:** Add description column with error message from `event.content`

### 4. Config singleton doesn't load .env ✅ FIXED
- **ID:** `51412b76-d55f-409d-95e5-b4e7c0bffa77`
- **Status:** ✅ FIXED
- **Evidence:** `Config.ts:28` now loads dotenv:
  ```typescript
  import { config } from 'dotenv';
  config();
  ```

### 5. 10 'as any' type bypasses across codebase ❌ NOT FIXED
- **ID:** `d6142aff-eced-4400-b38f-67314eec2ca6`
- **Status:** ❌ NOT FIXED (8 occurrences remain)
- **Evidence:** Found in:
  - `kernel/cli/index.ts:390,410`
  - `cli.ts:541`
  - `agent/extension/extension.ts:1109,1111,1115,1201`
  - `kernel/services/PiSDKExecutor.ts:42`

### 6. Duplicate DB connection config ❌ NOT FIXED
- **ID:** `dfb8bfb8-fd16-4145-a88f-97e06c60ad94`
- **Status:** ❌ NOT FIXED
- **Evidence:** Two separate Pool creations:
  - `kernel/db/DatabaseClient.ts` - uses Config singleton
  - `agent/extension/db.ts:29` - creates its own Pool with PSYPI_DB_* env vars

### 7. Hardcoded 'psypi' as created_by in 9 Kernel INSERT statements ✅ FIXED
- **ID:** `7025a6ea-9034-4e6e-8f9d-0b1512a697b0`
- **Status:** ✅ FIXED
- **Evidence:** All INSERT statements in `kernel/index.ts` now use `await this.getAgentId()`:
  ```typescript
  const agentId = await this.getAgentId();
  // ... INSERT ... VALUES (..., $agentId)
  ```

---

## Medium Issues

### 8. [Bug] psypi issue-add fails with 'column source does not exist' ❌ NOT FIXED
- **ID:** `f2363074-d076-4c5d-8c54-3ac24c8918ce`
- **Status:** ❌ NOT FIXED
- **Notes:** Schema mismatch between psypi code and actual database schema

### 9. [Bug] Agent 441140fe ran for 3 days without identity registration ⚠️ INVESTIGATED
- **ID:** `14ffe597-29fe-42b1-b283-84ed65f36acb`
- **Status:** ⚠️ Root cause identified, needs code fix
- **Notes:** Agent created records without identity registration. Needs guard in code.

### 10. Hardcoded 'nezha' references throughout codebase ⚠️ PARTIAL
- **ID:** `8eff58b9-8b37-4767-901b-efcb70974511`
- **Status:** ⚠️ PARTIALLY FIXED
- **Evidence:** Most references updated to 'psypi', but some remain:
  - Migration files still reference 'S-nezha-system' (expected)
  - CLI name is 'psypi' ✅

### 11. Inconsistent env var naming for DB config ✅ FIXED
- **ID:** `567ef05d-cac0-46c8-856e-9d60e7b2cabf`
- **Status:** ✅ FIXED
- **Evidence:** Now unified to `PSYPI_DB_*`:
  - `constants.ts:78-80`: `PSYPI_DB_HOST`, `PSYPI_DB_PORT`, `PSYPI_DB_NAME`
  - `agent/extension/db.ts:16-19`: Uses `PSYPI_DB_*`

### 12. Multiple integration issues ⚠️ PARTIAL
- **ID:** `6a781450-10a5-424a-983f-0ee36a35cb28`
- **Status:** ⚠️ PARTIALLY FIXED
- **Progress:**
  - ✅ SQL injection fixed
  - ❌ Dual database access still exists
  - ❌ Empty agent module (src/agent/index.ts is 0 lines)
  - ❌ No tests (0% coverage)

### 13. [LEARN] psypi 集成完成 ✅ DONE
- **ID:** `a823faa8-491c-4a16-a348-3b4083fda119`
- **Status:** ✅ Can be closed

### 14. [LEARN] psypi areflect magic works ✅ DONE
- **ID:** `a3a7edca-0f50-4916-ba6c-7eed4a39c2ee`
- **Status:** ✅ Can be closed

### 15. psypi: kernel/index.ts Set<string> needs downlevelIteration ✅ FIXED
- **ID:** `b8db9983-5a83-4cd3-85e7-675f11348c09`
- **Status:** ✅ FIXED (code compiles now)

---

## Issues to Close (Resolved in Code)

1. `2138d4e3` - Hardcoded DB password ✅
2. `69db3707` - SQL Injection ✅
3. `51412b76` - Config singleton doesn't load .env ✅
4. `7025a6ea` - Hardcoded 'psypi' as created_by ✅
5. `567ef05d` - Inconsistent env var naming ✅
6. `b8db9983` - Set<string> downlevelIteration ✅
7. `a823faa8` - [LEARN] psypi 集成完成 ✅
8. `a3a7edca` - [LEARN] psypi areflect magic works ✅

## Issues Still Needing Work

1. `a9c31dd1` - Tool Failed issues have no description ❌
2. `d6142aff` - 'as any' type bypasses ❌
3. `dfb8bfb8` - Duplicate DB connection config ❌
4. `f2363074` - Schema mismatch (column source) ❌
5. `14ffe597` - Agent identity registration guard ❌
6. `6a781450` - Multiple integration issues (partial) ⚠️
