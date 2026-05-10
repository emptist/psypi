# Inter-Review Research Findings

## Current Implementation

### What works
1. **inter_review.gleam** - 337 lines, clean Gleam code
2. **DB table** - inter_reviews with status tracking (pending/completed/failed)
3. **psypi-commit tool** - triggers review via commit_tool()

### What doesn't work / needs redesign
1. **External LLM** - uses `P-tencent/hy3-preview:free-psypi` (should be Monitor)
2. **Async flow** - stores request in DB, external process picks up (not real-time)
3. **Limited context** - just passes context string, no git diff, no project context

## Current Flow
```
psypi-commit → request_review() → SQL: request_inter_review() 
                                            ↓
                                     DB (inter_reviews table)
                                            ↓
                              external LLM picks up async (separately)
```

## External LLM Location
- Model: `P-tencent/hy3-preview:free-psypi`
- Called via: SQL function, not direct LLM call
- Location in code:
  - `inter_review.gleam:332` - reviewer_id param
  - `context.gleam:9` - monitor_id() returns this ID

## Compare with Monitor
- **callMonitor** in extension_generator.gleam - uses `ctx.model` (worker's model)
- Real-time, synchronous
- Can access git, project context via JS

## Key Differences

| Aspect | Current inter_review | Monitor callMonitor |
|--------|---------------------|---------------------|
| LLM | External (P-tencent) | Same as worker (ctx.model) |
| Flow | Async (DB + separate process) | Synchronous (in same session) |
| Context | Limited (passed string) | Full (can query git, DB, etc) |
| Response time | Not real-time | Immediate |

## What's in DB
- inter_reviews table: id, task_id, status, summary, overall_score, requested_at
- Request stores: reviewer_id, context (JSON), branch

## Recommendation
Replace external LLM with Monitor callMonitor:
- Move psypi-commit tool to extension_generator.gleam (where callMonitor exists)
- Gather full context (git diff, project info, activity)
- Call callMonitor directly
- Return immediate PASS/FAIL + feedback

This matches the design in docs/INTER_REVIEW_DESIGN.md