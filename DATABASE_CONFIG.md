# Database Configuration

## Overview

Psypi uses a **single source of truth** approach for database configuration: the `.env` file.

## Configuration Method

### The `.env` File (Single Source of Truth)

All database configuration is done via environment variables in `.env`:

```bash
# Database Configuration
PSYPI_DB_HOST=localhost
PSYPI_DB_PORT=5432
PSYPI_DB_NAME=nezha        # Change to 'psypi' when migrating later
PSYPI_DB_USER=postgres
PSYPI_DB_PASSWORD=
```

## Design Decisions

### Why No Fallbacks?

- **Simplicity**: No hidden defaults, what you set is what you get
- **Explicit**: Must configure via `.env` (loaded by dotenv)
- **Single source of truth**: Only one place to look when debugging

### Current Database: `nezha`

We're currently using the `nezha` database because:
- It already contains data (tasks, issues, etc.)
- Migration to `psypi` database will happen later when psypi is stable
- **To migrate later**: Just change `PSYPI_DB_NAME=psypi` in `.env`

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

## Migration Path

When ready to migrate from `nezha` to `psypi` database:

1. Create new `psypi` database: `createdb psypi`
2. Run migrations: `psql psypi -f migration.sql`
3. Update `.env`: `PSYPI_DB_NAME=psypi`
4. Restart psypi

That's it! 🚀
