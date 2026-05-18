# Tool Test Results — Complete (35 tools tested)

## Working (output is useful)
1. ✅ psypi-somatic-id — Clean ID output
2. ✅ psypi-autonomic-id — Clean ID output
3. ✅ psypi-task-add — Returns task ID
4. ✅ psypi-task-complete — Returns confirmation
5. ✅ psypi-autonomic-status — Clean message
6. ✅ psypi-meeting-add — Returns meeting ID
7. ✅ psypi-broadcast-send — Returns broadcast ID
8. ✅ psypi-areflect — Returns summary JSON
9. ✅ psypi-direct-agentbot — Returns confirmation

## Working but output is unusable (raw JSON, wastes context)
10. ⚠️ psypi-tasks — Massive nested JSON
11. ⚠️ psypi-stats-show — "Tasks:105 Issues:104..." no formatting
12. ⚠️ psypi-autonomic-health — Raw JSON
13. ⚠️ psypi-autonomic-alerts — Raw JSON
14. ⚠️ psypi-autonomic-stats — Raw JSON, all zeros
15. ⚠️ psypi-autonomic-suggest — Massive nested JSON
16. ⚠️ psypi-skill-list — Massive nested JSON
17. ⚠️ psypi-skill-get — Error: Skill not found
18. ⚠️ psypi-meetings — Massive nested JSON
19. ⚠️ psypi-meeting-get — Raw JSON
20. ⚠️ psypi-meeting-opinions — Raw JSON nested linked list
21. ⚠️ psypi-broadcasts — Raw JSON nested linked list
22. ⚠️ psypi-agents — Raw JSON deeply nested linked list
23. ⚠️ psypi-hooks-list — Massive nested JSON
24. ⚠️ psypi-hooks-active — Massive nested JSON
25. ⚠️ psypi-doc-list — Raw JSON

## Broken (errors)
26. ❌ psypi-issues — "there is no parameter $0" — SQL binding error
27. ❌ psypi-issue-add — Missing required params (description, issue_type) — tool definition mismatch
28. ❌ psypi-skill-get — "Skill not found" — can't find by ID
29. ❌ psypi-skill-search — Returns empty `{}` — search not working
30. ❌ psypi-learn-save — "Cannot read properties of undefined" — crashes
31. ❌ psypi-memory-search — Returns placeholder `{count}` — broken template
32. ❌ psypi-clear-directives — "column 'active' does not exist" — DB schema mismatch
33. ❌ psypi-issue-count — Returns "Count: 0" even after adding issue — counting logic wrong

## Partially working
34. ⚠️ psypi-consult-autonomic — Returns "[Autonomic] psypi-tasks" — Monitor LLM responds but output is minimal
35. ⚠️ psypi-commit — Review runs but scores 0/100 — scoring logic broken

## Summary
- **9/35** tools work with useful output
- **12/35** tools work but return unusable raw JSON
- **8/35** tools are broken (errors)
- **6/35** tools are partially working

## Root Causes
1. **Raw JSON output** — Tools return `JSON.stringify()` of DB records without formatting
2. **DB schema mismatches** — Tools reference columns that don't exist or have wrong names
3. **Broken templates** — `psypi-memory-search` returns literal `{count}` instead of actual count
4. **SQL binding errors** — `psypi-issues` has parameter binding issues
5. **Missing required params** — Tool definitions don't match DB schema requirements
