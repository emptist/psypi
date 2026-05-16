# Plan: Fix Broken Tools & Improve System

## Overview
Multiple tools are broken due to schema mismatches, missing columns, and outdated documentation. This plan fixes them systematically.

## Current State
- 79 open issues (many are test entries from migration)
- 103 total issues, 103 tasks, 188 skills, 53 meetings
- `table_documentation` table exists with 24 rows but is outdated
- `psypi-basics` skill needs maintenance
- `areflect` tool works but could be improved

## Phase 1: Issue Tools (Priority: High)

### Task 1.1: Add severity/type filtering to psypi-issues
**Description:** Currently `psypi-issues` only supports `status` filter. Add `severity` and `issue_type` filters.
**Files:** `src/issue.gleam`, `extension_generator.gleam`
**Acceptance criteria:**
- [ ] `psypi-issues --severity critical` works
- [ ] `psypi-issues --type bug` works
- [ ] `psypi-issues --status open --severity high` works (combined)

### Task 1.2: Add pagination to psypi-issues
**Description:** With 79+ issues, need pagination support.
**Files:** `src/issue.gleam`
**Acceptance criteria:**
- [ ] `psypi-issues --limit 10 --offset 20` works
- [ ] Default limit is 50, max is 100

### Task 1.3: Add bulk resolve to psypi-issues
**Description:** Allow resolving multiple issues at once.
**Files:** `src/issue.gleam`
**Acceptance criteria:**
- [ ] `psypi-issue-resolve --id <id1> --id <id2>` works
- [ ] `psypi-issues-resolve --status open --severity low --before 2026-05-01` works (bulk)

## Phase 2: Table Documentation (Priority: High)

### Task 2.1: Sync table_documentation with actual schema
**Description:** The `table_documentation` table has 24 rows but is missing new tables and has outdated info.
**Files:** SQL migration, `table_documentation` table
**Acceptance criteria:**
- [ ] All current tables are documented
- [ ] `key_columns` JSON is accurate for each table
- [ ] `cli_commands` are up to date
- [ ] `tags` are consistent

### Task 2.2: Add table_documentation Pi tool
**Description:** Create a tool to query table_documentation from the TUI.
**Files:** New Gleam module `src/table_documentation.gleam`
**Acceptance criteria:**
- [ ] `psypi-table-doc --table issues` shows documentation
- [ ] `psypi-table-doc --tag cli` shows all CLI-related tables
- [ ] `psypi-table-doc --search "issue"` finds relevant tables

## Phase 3: psypi-basics Skill (Priority: Medium)

### Task 3.1: Update psypi-basics skill
**Description:** The skill is outdated. Update with current tool names and usage.
**Files:** `.pi/skills/psypi-basics/SKILL.md`
**Acceptance criteria:**
- [ ] All tool names match current implementation
- [ ] Examples work correctly
- [ ] Includes new tools (areflect, table-doc, etc.)

### Task 3.2: Add skill self-test
**Description:** Add a way to verify the skill is in sync with actual tools.
**Files:** `.pi/skills/psypi-basics/SKILL.md`
**Acceptance criteria:**
- [ ] Skill includes a "verify" command that checks tool availability
- [ ] Mismatches are reported clearly

## Phase 4: Areflect Tool Improvements (Priority: Medium)

### Task 4.1: Improve areflect issue creation
**Description:** Currently creates issues with default severity "medium". Should parse severity from marker.
**Files:** `src/areflect.gleam`
**Acceptance criteria:**
- [ ] `[ISSUE] [critical] Title` creates critical issue
- [ ] `[ISSUE] [high] Title` creates high severity issue
- [ ] Default remains medium if no severity specified

### Task 4.2: Add areflect stats
**Description:** Show summary of what was created.
**Files:** `src/areflect.gleam`
**Acceptance criteria:**
- [ ] Returns count of learnings/issues/tasks created
- [ ] Lists issue IDs created

## Phase 5: Clean Up Test Data (Priority: Low)

### Task 5.1: Remove test issues
**Description:** Many open issues are test entries. Clean them up.
**Files:** SQL
**Acceptance criteria:**
- [ ] Test issues with empty titles removed
- [ ] Test issues with "test" in title removed
- [ ] Real issues preserved

## Verification
After all phases:
- [ ] `psypi-issues` works with all filter combinations
- [ ] `table_documentation` is complete and accurate
- [ ] `psypi-basics` skill is current
- [ ] `areflect` parses severity from markers
- [ ] Test data cleaned up
- [ ] Build passes: `rm -rf build/ && gleam build`
- [ ] Extension regenerated: `gleam run -m extension_generator`
