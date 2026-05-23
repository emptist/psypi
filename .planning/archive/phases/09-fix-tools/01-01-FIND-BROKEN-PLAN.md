# Phase 09: Fix Broken & Missing Pi Tools

## Context
From docs/archive/GLEAM-CODE-REVIEW-2026-05-08.md:
- **21 tools** currently working (we just added 4)
- **Broken tools** (wrong args): psypi-issue-add, psypi-learn, psypi-skill-build, psypi-skill-list, psypi-issue-resolve
- **Missing tools**: psypi-autonomous, psypi-status, psypi-project, psypi-visits, psypi-doc-list

## Objective
Fix broken tools and add missing tools systematically. Leave out psypi-commit and inter-review (as requested).

## Rules
- Build must pass with `--warnings-as-errors`
- Do NOT test (to save system resources)
- Reference Gleam code quality guidelines
- Use PiToolCall pattern from gleam-pi-tool-generator skill

---

## Task 1: Fix psypi-issue-add

**Location**: src/psypi/issue.gleam
**Problem**: 4 missing args
**Action**: Check issue.add() signature, update PiToolCall args to match
**Verify**: gleam build passes

## Task 2: Fix psypi-learn

**Location**: src/psypi/learning.gleam  
**Problem**: 3 missing args
**Action**: Check learning.save() signature, update PiToolCall args
**Verify**: gleam build passes

## Task 3: Fix psypi-skill-list

**Location**: src/psypi/skill.gleam
**Problem**: Wrong arg type (enum vs no-arg)
**Action**: Check skill.list() signature, update PiToolCall args
**Verify**: gleam build passes

## Task 4: Fix psypi-issue-resolve

**Location**: src/psypi/issue.gleam
**Problem**: 1 missing arg
**Action**: Check issue.resolve() signature, update PiToolCall args
**Verify**: gleam build passes

## Task 5: Add psypi-doc-list

**Location**: Likely src/psypi/code_version.gleam or new module
**Problem**: Missing tool
**Action**: Check if doc_list function exists, add PiToolCall if not
**Verify**: gleam build passes

## Task 6: Add psypi-status

**Location**: src/psypi/stats.gleam or new module
**Problem**: Missing tool
**Action**: Check if stats functions exist, add PiToolCall
**Verify**: gleam build passes

## Task 7: Add psypi-visits (skip if complex)

**Status**: Low priority, skip if database table doesn't exist

## Task 8: Add psypi-autonomous (skip if complex)

**Status**: Complex - requires AI coordination, skip for now

---

## Verification
After ALL tasks: `gleam build --warnings-as-errors` passes

## Success Criteria
- All broken tools fixed (args match function signatures)
- At least psypi-doc-list and psypi-status added
- Build clean
- Do NOT test in Pi (to save resources)