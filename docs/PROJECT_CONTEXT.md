---
description: Context and overview of the psypi project
---

# Project Context for Psypi

## Current Project: psypi (Psyche + Pi)

**Description**: Unified AI coordination system combining kernel (DB, tasks, issues, skills) + autonomous agent (Pi executor)

**Status**: ✅ Unified and working - single CLI tool replacing `nezha` and `nupi`

**Current Focus**: 
- Fixing build errors (4 TypeScript errors identified)
- Testing inter-review functionality
- Migrating git hooks to `psypi commit` command

## Key Project Details

- **Package Manager**: pnpm (NOT npm)
- **Database**: PostgreSQL (source of truth)
- **Build time**: ~10s with pnpm
- **Inner AI Model**: tencent/hy3-preview:free via OpenRouter
- **Total Tasks**: 363+ pending

## Current Issues Being Worked On

1. Build-blocking TypeScript errors (4 total)
2. Inter-review column naming confusion
3. Migrating hooks to `psypi commit` command (COMPLETED)

## Project Structure

- `src/cli.ts` - Main CLI commands
- `src/kernel/` - Core kernel (DB, services)
- `src/agent/` - Pi agent extension
- `docs/` - Documentation and plans