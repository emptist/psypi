---
phase: 10-inter-review
type: research
---

<objective>
Understand current inter_review implementation before redesign.

Purpose: Don't reinvent - find what works, what doesn't, what to keep.
Output: FINDINGS.md with current state analysis.
</objective>

<execution_context>
@~/.claude/skills/create-plans/workflows/research-phase.md
</execution_context>

<context>
@docs/INTER_REVIEW_DESIGN.md
@docs/MONITOR_MODES.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Find inter_review related code</name>
  <files>src/psypi/inter_review.gleam</files>
  <action>Search for all inter_review related code: functions, SQL calls, tool definitions. Document what it currently does.</action>
  <verify>grep -r "inter_review" src/psypi/ returns all matches</verify>
  <done>List of all inter_review functions + their purpose</done>
</task>

<task type="auto">
  <name>Task 2: Find external LLM call</name>
  <files>src/psypi/inter_review.gleam</files>
  <action>Find where external LLM is called. Document the model, endpoint, parameters.</action>
  <verify>grep for LLM/API calls in inter_review.gleam</verify>
  <done>Current external LLM details documented</done>
</task>

<task type="auto">
  <name>Task 3: Check DB schema for inter_reviews</name>
  <files>docs/, src/psypi/</files>
  <action>Find inter_reviews table schema. What fields? How used?</action>
  <verify>grep "inter_reviews" in codebase</verify>
  <done>Schema documented</done>
</task>

<task type="auto">
  <name>Task 4: Compare with Monitor callMonitor</name>
  <files>src/psypi/extension_generator.gleam</files>
  <action>Document how callMonitor works in extension.js. Compare to inter_review LLM call.</action>
  <verify>grep callMonitor extension_generator.gleam</verify>
  <done>Differences documented</done>
</task>

</tasks>

<verification>
- [ ] All inter_review functions documented
- [ ] External LLM call documented
- [ ] DB schema documented
- [ ] Comparison with callMonitor done
</verification>

<success_criteria>
Complete understanding of current inter_review system
</success_criteria>

<output>
Create .planning/phases/10-inter-review/10-01-FINDINGS.md