# Phase 10 Plan 04: Learning/Education in Inter-Review Summary

**Added education suggestions to inter-review**

## Accomplishments
- Created migration for review_learnings table (design ready, not applied)
- Updated psypi-commit prompt to ask Monitor for EDUCATION_SUGGESTION
- Monitor now includes learning/education feedback in review response

## Files Created/Modified
- `src/kernel/db/migrations/080_review_learnings.sql` - Table design (not applied yet)
- `src/psypi/extension_generator.gleam` - Updated prompt
- `extension.js` - Regenerated

## What's Working
- Monitor detects patterns needing education
- Includes EDUCATION_SUGGESTION in response
- Agentbot sees what to learn in review feedback

## What's Next (v2)
- Apply migration to create table
- Store patterns in DB for tracking
- Aggregate patterns for system-wide learning

## Remaining (from expanded roles)
- Statistics (model quality, language efficiency)
- Self-design (find own jobs)