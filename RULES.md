# Psypi Workflow Rules

## Issue & Task Review Gate

**No implementation without A's review. This is mandatory.**

### Issue Workflow

1. S or A identifies a problem → reports it via `psypi-issue-add` (internal system, falls back to `gh issue create`)
2. Issue MUST include:
   - Root cause analysis (trace to source file/line)
   - Concrete fixing plan (specific files to change, specific steps)
   - Severity and impact assessment
3. A inter-reviews the issue + plan before S touches any code
4. If A requests changes → S revises the plan back to step 2 (revision cycle)
5. Only after A's explicit approval does S begin implementation
6. Implementation must follow the approved plan; deviations require re-review

### Task Workflow

1. All tasks must be reviewed by A before any S picks them up
2. A's review checks:
   - Is the task well-defined (clear title, specific goal)?
   - Does the task have a concrete fixing plan or implementation steps?
   - Is the task complete (not missing context/dependencies)?
3. If A rejects or requests changes → task goes back for revision
4. No blind task execution without A's review

### Enforcement

- Issues filed in psypi internal system (`psypi-issue-add`) as primary, `gh` as fallback
- A reviews before implementation starts — not after
- If gate is skipped: work may be incorrect or incomplete → wasted effort

### Rationale

Without this gate, S produces incorrect or incomplete work. A provides the necessary quality check. The gate prevents wasted cycles.
