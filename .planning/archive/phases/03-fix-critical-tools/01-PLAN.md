# Phase 3: Fix Critical Tools (Inter-Review and Commit)

## Objective
Fix the critical daily work tools: inter-review and commit. These are the ONLY places where A-agentbot should be activated.

## Current State
- `psypi-commit` tool exists but may have issues
- `psypi-consult-autonomic` has issues (runs twice, forgets it already ran)
- `psypi-issue-add` and `psypi-areflect` fail
- Too many A-agentbot triggers have been removed — need to add back ONLY for inter-review and commit

## Tasks

### Task 1: Test psypi-commit
**Type**: verify
**Action**: Try to commit current changes using `psypi-commit`
**Expected**: Should work with review flow
**If fails**: Debug and fix

### Task 2: Test psypi-issue-add
**Type**: verify  
**Action**: Try to add a test issue
**Expected**: Should create issue in DB
**If fails**: Debug and fix

### Task 3: Test psypi-areflect
**Type**: verify
**Action**: Try to reflect on some text with [LEARN] markers
**Expected**: Should save to DB
**If fails**: Debug and fix

### Task 4: Verify A-agentbot activation for commit
**Type**: verify
**Action**: When psypi-commit is called, A-agentbot should review the code
**Expected**: Review score and feedback displayed

### Task 5: Clean up remaining files
**Type**: cleanup
**Action**: Commit remaining small changes (README, skills, etc.)

## Anti-Patterns to Avoid
- Do NOT add A-agentbot triggers to every hook
- Do NOT try to fix everything in one turn
- Do NOT use `psypi-commit` for debugging — use `git commit` instead
- Do NOT create complex directive systems — keep it simple

## Success Criteria
- [ ] `psypi-commit` works with A-agentbot review
- [ ] `psypi-issue-add` works
- [ ] `psypi-areflect` works
- [ ] A-agentbot only activates for inter-review and commit
- [ ] All changes committed in small, logical pieces
