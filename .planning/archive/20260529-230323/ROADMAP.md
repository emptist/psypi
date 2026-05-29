# Phase 1: Inter-Review & Commit Separation

## Objective
Decouple inter-review from psypi-commit. Simplify commit to immediate execution with agent ID tagging. Make inter-review A-bot's primary autonomous job.

## Context
- @src/tool_commit.gleam — current two-phase commit (broken)
- @src/inter_review.gleam — review request/response (response never written)
- @src/agent_identity.gleam — semantic_id() with global ID bug
- @src/agent_identity_types.gleam — duplicate semantic_id()
- @src/extension_generator.gleam — psypi-commit tool definition
- @src/hook_on_agent_end.gleam — A-bot trigger logic
- @src/a_orchestrator.gleam — A-bot workflow (no review step)
- @docs/design_inter_review_commit_separation.md — design doc

## Plan Structure
- 01-01: Simplify tool_commit.gleam (remove two-phase, add agent ID)
- 01-02: Fix semantic_id() global ID format (G moves to project position)
- 01-03: Update extension_generator.gleam (psypi-commit tool def)
- 01-04: Add inter-review step to A-bot workflow
