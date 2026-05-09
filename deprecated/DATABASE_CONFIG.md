# Database Configuration

## Overview

Psypi uses a **single source of truth** approach for database configuration: the `.env` file.

## Configuration Method

### The `.env` File (Single Source of Truth)

All database configuration is done via environment variables in `.env` (migrated to `psypi` database on 2026-05-03):

```bash
# Database Configuration
PSYPI_DB_HOST=localhost
PSYPI_DB_PORT=5432
PSYPI_DB_NAME=psypi        # Migrated from nezha on 2026-05-03
PSYPI_DB_USER=postgres
PSYPI_DB_PASSWORD=
```

## Design Decisions

### Why No Fallbacks?

- **Simplicity**: No hidden defaults, what you set is what you get
- **Explicit**: Must configure via `.env` (loaded by dotenv)
- **Single source of truth**: Only one place to look when debugging

### Current Database: `psypi` (Migrated from `nezha` on 2026-05-03)

We are now using the `psypi` database:
- Migration completed on 2026-05-03
- All data has been migrated from `nezha` database
- The old `nezha` database can be considered legacy

**Migration is complete** - no further action needed.

### No Hardcoded Names

The code contains **ZERO hardcoded database names**. Previously:
```typescript
// ❌ OLD - hardcoded
database: database || 'psypi',
database: 'nezha',
```

Now:
```typescript
// ✅ NEW - from .env only
database: process.env.PSYPI_DB_NAME,
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PSYPI_DB_HOST` | Database host | Yes |
| `PSYPI_DB_PORT` | Database port | Yes |
| `PSYPI_DB_NAME` | Database name | Yes |
| `PSYPI_DB_USER` | Database user | Yes |
| `PSYPI_DB_PASSWORD` | Database password | Optional |

## Files Modified

- `src/agent/extension/db.ts` - Reads from `process.env.PSYPI_*`
- `src/kernel/config/Config.ts` - Reads from `process.env[ENV_KEYS.*]`
- `src/kernel/config/constants.ts` - Defines `ENV_KEYS` mapping to `PSYPI_*`
- `src/kernel/config/types.ts` - Updated `DbConfig` interface (all optional now)

## Migration (Completed)

The migration from `nezha` to `psypi` database was completed on **2026-05-03**.

Steps that were performed:
1. ✅ Created new `psypi` database: `createdb psypi`
2. ✅ Ran migrations: `psql psypi -f migration.sql`
3. ✅ Updated `.env`: `PSYPI_DB_NAME=psypi`
4. ✅ Restarted psypi

No further migration action is needed. The system is now running on the `psypi` database.
