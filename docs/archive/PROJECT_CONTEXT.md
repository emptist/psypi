---
description: Context and overview of the psypi project
---

# Project Context for Psypi

## Current Project: psypi (Psyche + Pi)

**Description**: Unified AI coordination system combining kernel (DB, tasks, issues, skills) + autonomous agent (Pi executor)

**Status**: ✅ Unified and working - single CLI tool with **Gleam core**!

**Current Focus**: 
- **Natural Gleam migration** (see `docs/MIGRATION-TS-TO-GLEAM-2026.md`)
- Deleting TypeScript bloat
- Growing Gleam modules (currently 380 lines, target: 2,000)

## Key Project Details

- **Package Manager**: pnpm (NOT npm)
- **Database**: PostgreSQL (source of truth)
- **Build time**: ~10s with pnpm
- **Gleam**: 380 lines (1.4%) - Core logic (review, session, CLI)
- **TypeScript**: 26,493 lines (98.6%) - Being migrated to Gleam
- **Ratio**: 1:70 (Gleam:TS) - Target: 1:5 by end of 2026
- **God in the sky**: Gleam `run_review()` handles all reviews!

## Architecture

### Gleam Core (Small & Unbreakable!)
- `gleam/psypi_core/src/` - 11 modules, all < 100 lines!
- Handles: review, session mgmt, CLI commands, identity
- **Philosophy**: Small + Pure = Resilience!

### TypeScript Bridge
- `src/common/gleam-bridge.ts` - 13 lines, imports Gleam modules
- `src/kernel/` - Services being migrated to Gleam
- `src/agent/` - Pi extension (uses Gleam via bridge)

## Project Structure

- `gleam/psypi_core/src/` - Gleam modules (380 lines, growing!)
- `src/cli.ts` - Main CLI (candidate for deletion, use Gleam CLI)
- `src/kernel/` - Core kernel (DB, services) - being migrated
- `src/agent/` - Pi agent extension
- `docs/` - Documentation (cleaned up 2026-05-03)
- `docs/archive/` - Old docs and completed plans

## Migration Status

✅ **Completed**:
- nezha → psypi database migration
- Inner AI → Gleam review (God in the sky!)
- Session ID system (two methods)
- Agent identity system (single source of truth)

🚀 **In Progress**:
- Natural Gleam growth (touch TS = rewrite in Gleam)
- Deleting TS bloat (target: 10,000 lines from 26,493)
- See `docs/MIGRATION-TS-TO-GLEAM-2026.md` for full plan