# Memory & Learning System Analysis

**Date**: 2026-05-31
**Author**: S-bot investigation

## Overview

psypi has two separate storage systems for knowledge, plus several informal ones. This document maps them and identifies problems.

## Storage Systems

### 1. `memory` table — Free-text Learnings

**How it's populated**: `psypi-learn-save` Pi tool, `psypi-areflect` auto-extraction, traenupi migration

**Schema highlights**:
- `content` (text) — the learning itself
- `source` (text) — 'learn', 'areflect', 'traenupi'
- `tags` (text[]) — searchable tags
- `importance` (int 1-10) — set by AI at save time
- `embedding` (vector 768) — for semantic search
- `agent_id`, `session_id`, `project_id` — provenance
- `metadata` (jsonb) — flexible extra data

**Current data**: 65 rows (39 learn, 23 areflect, 3 traenupi)

**Strengths**: Flexible, searchable (keyword + semantic), importance-ranked, project-isolated

**Problems**:
- Becomes a dump for everything — process rules, bug findings, design decisions, workflow knowledge
- No curation mechanism — old/stale entries accumulate
- No connection to action — a memory entry doesn't create an issue or task
- AIs over-use it because there's no guidance on what belongs here

### 2. `learning_insights` table — Structured Insights

**How it's populated**: External AI (trae-ai during system review), not by any Pi tool

**Schema highlights**:
- `insight_type` (varchar) — 'architecture', 'pattern', etc.
- `title`, `content` — the insight
- `evidence` (jsonb) — supporting evidence
- `priority` (int 1-10), `confidence` (float 0-1)
- `is_applied` (bool), `applied_at`, `expires_at` — lifecycle

**Current data**: All entries have `is_applied = false` — recorded but never acted on

**Problems**:
- **Completely disconnected from any workflow** — no tool reads or writes this table
- No Gleam module uses it
- Was populated once by an external AI review, never touched again
- The `is_applied` / `expires_at` fields suggest a lifecycle that was never implemented

### 3. `agent_jobs` table — Behavioral Rules (Informal Memory)

**What it stores**: Prioritized behavioral guidelines for A and S bots

**Why it matters**: This is where process rules and "how we work" knowledge should live. Jobs are loaded every cycle and directly influence behavior. More effective than memory entries because they're actionable.

### 4. `table_documentation` table — Schema Knowledge

**What it stores**: Purpose, usage, key columns, related tables, example queries for each DB table

**Why it matters**: This is where knowledge about the database itself should live. Currently 152 entries but many are auto-generated stubs.

### 5. `agent_souls` table — Identity & Responsibilities

**What it stores**: A and S's identity, responsibilities, values, behavior guidelines

**Why it matters**: This is where "who does what" knowledge lives. The soul content is loaded into prompts every cycle.

### 6. `docs/` directory — Long-form Documentation

**What it stores**: AGENTS.md, README.md, design docs, session summaries, handover docs

**Why it matters**: Comprehensive reference material. Not loaded into prompts automatically — must be read explicitly.

## The Routing Problem

When an AI learns something, it currently has no guidance on where to put it. The `psypi-learn-save` tool always writes to `memory`, regardless of what the knowledge actually is.

**What should go where**:

| Knowledge Type | Right Destination | Wrong Destination |
|---|---|---|
| Process rules ("always do X before Y") | `agent_jobs` | `memory` |
| Bug findings | `issues` | `memory` |
| Design decisions | docs / A's soul | `memory` |
| Schema knowledge | `table_documentation` | `memory` |
| Architecture insights | `learning_insights` (if connected to workflow) | `memory` |
| Genuine memories ("I learned that...") | `memory` | — |
| Workflow state | `memory` with `session_id` | — |

## Recommendations

### Short-term
1. Add an A job: "Periodically review `memory` table entries. Route process rules to `agent_jobs`, bug findings to `issues`, delete stale entries."
2. Add an A job: "When S saves a learning, check if it belongs in `agent_jobs` or `issues` instead."
3. Connect `learning_insights` to the review workflow — A should read unapplied insights during system-review.

### Medium-term
4. Update `psypi-learn-save` tool to accept a `target` parameter (memory, jobs, issues) and route accordingly.
5. Implement `is_applied` lifecycle for `learning_insights` — A should mark insights as applied when they influence a decision.
6. Memory maintenance: A should periodically search for stale memories (old, low importance, never referenced) and flag them for deletion.

### Long-term
7. Embedding-based deduplication: before saving a new memory, search for similar existing entries and update instead of duplicating.
8. Memory → Issue auto-creation: if a memory entry describes a problem pattern, A should create an issue for it.
