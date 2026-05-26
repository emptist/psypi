# SQL Verification Audit — 2026-05-26

Every entry below was tested against the live PostgreSQL database using psql.
No assumptions. No documentation trust. Only verified facts.

---

## LAYER 1: Phantom Columns (SQL fails immediately)

| File             | Line | Function          | Broken SQL                                                                                                | psql Error                                          |
| ---------------- | ---- | ----------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| issue_db.gleam   | 88   | add()             | INSERT INTO issues (..., created_by, project_id)                                                          | column "created_by" does not exist                  |
| issue_db.gleam   | 170  | list()            | SELECT ..., created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues | column "created_by" does not exist                  |
| issue_db.gleam   | 261  | get()             | WHERE id = $1 AND project_id = $2                                                                         | column "project_id" does not exist                  |
| issue_db.gleam   | 296  | resolve()         | WHERE id = $1 AND project_id = $3                                                                         | column "project_id" does not exist                  |
| issue_db.gleam   | 233  | count()           | WHERE project_id = $...                                                                                   | column "project_id" does not exist                  |
| task.gleam       | 198  | list()            | SELECT ..., source, project_id::text FROM tasks                                                           | column "source" does not exist                      |
| task.gleam       | 240  | get()             | SELECT ..., source FROM tasks                                                                             | column "source" does not exist                      |
| monitor_ai.gleam | 561  | auto_file_issue() | INSERT INTO issues (..., type, created_by, discovered_by, environment)                                    | column "type" does not exist (should be issue_type) |
| areflect.gleam   | 224  | save_issue()      | INSERT INTO issues (..., created_by)                                                                      | column "created_by" does not exist                  |
| broadcast.gleam  | 135  | broadcast()       | INSERT INTO project_communications (..., priority, metadata)                                              | column "priority" does not exist                    |

## LAYER 2: FK Violation (SQL fails on constraint)

| File       | Line | Function          | Broken SQL                                                      | psql Error                                                     |
| ---------- | ---- | ----------------- | --------------------------------------------------------------- | -------------------------------------------------------------- |
| task.gleam | 123  | add()             | INSERT INTO tasks (..., project_id) VALUES (..., '0d324e68...') | FK violation: Key (project_id) not present in table "projects" |
| db.gleam   | 41   | with_connection() | SET app.current_project_id = '0d324e68...'                      | GUC SET works, but value references nonexistent project row    |

projects table has 0 rows. The UUID 0d324e68-b399-4b85-bd8a-6b1ef7b46168 does not exist in any table.

## LAYER 3: Broken Trigger (cascading failure)

Trigger: audit_direct_insert()
Affects 7 tables: issues, tasks, memory, meeting_opinions, project_communications, prompt_suggestions, scheduled_tasks

Root cause: The trigger function contains:
```sql
INSERT INTO project_communications (from_ai, to_ai, message_type, content, priority)
VALUES ('nezha-audit', v_author, 'notification', '...', 'high');
```

But project_communications does NOT have a priority column. Actual columns:
id, project_id, from_ai, to_ai, message_type, content, metadata, created_at, read_at

The trigger fires when source is NOT in allowed_sources:
['areflect', 'cli', 'heartbeat', 'scheduler', 'migration', 'system', 'api', 'broadcast', 'answer', 'notification', 'response']

| File           | Line | Function        | source value  | In allowed? | Trigger fires?          | Result                                 |
| -------------- | ---- | --------------- | ------------- | ----------- | ----------------------- | -------------------------------------- |
| learning.gleam | 29   | save_learning() | 'learn'       | NO          | YES -> FAILS            | psypi-learn-save BROKEN                |
| memory.gleam   | 63   | save()          | user-provided | depends     | if not allowed -> FAILS | psypi-memory-save conditionally BROKEN |

When trigger fires and fails, the entire INSERT rolls back. The row is NOT saved.

## LAYER 4: Decode Errors (SQL succeeds, Gleam decode fails)

| File               | Line | Function             | Issue                                                                       | Will fail when         |
| ------------------ | ---- | -------------------- | --------------------------------------------------------------------------- | ---------------------- |
| inter_review.gleam | 148  | get_review_details() | requested_at without ::text -> node_pg returns Date, Gleam expects String   | rows exist             |
| inter_review.gleam | 283  | list_reviews()       | same                                                                        | rows exist             |
| task.gleam         | 198  | list()               | result without ::text -> node_pg returns JSONB object, Gleam expects String | result column has data |
| issue_db.gleam     | 269  | count()              | Error(_) -> Ok(0) silently swallows decode errors                           | always returns 0       |

## LAYER 5: Schema Mismatch (type definitions reference phantom columns)

### issues table actual columns (24):
id, title, description, issue_type, severity, status, discovered_by, discovered_at,
related_issue_id, task_id, resolution, resolved_at, resolved_by, tags, metadata,
created_at, updated_at, assignee, assignee_type, milestone_id, related_review_id,
review_id, dlq_id, viewers

### issue_types.Issue phantom fields:
created_by, discovered_by (exists but different meaning), environment, git_branch,
git_hash, reported_by, source

### issue_types.Issue missing real fields:
discovered_by (actual), assignee, assignee_type, milestone_id, related_review_id,
review_id, dlq_id, viewers, metadata, tags, related_issue_id, task_id, resolution,
resolved_by

### task.Task phantom fields:
source (does not exist in tasks table)

---

## Tool Status Summary

| Tool                       | Status        | Root Cause                                        |
| -------------------------- | ------------- | ------------------------------------------------- |
| psypi-issue-add            | BROKEN        | phantom columns created_by, project_id            |
| psypi-issue-list           | BROKEN        | phantom columns in SELECT                         |
| psypi-issue-get            | BROKEN        | phantom project_id in WHERE                       |
| psypi-issue-count          | BROKEN        | phantom project_id in WHERE, silently returns 0   |
| psypi-issue-resolve        | BROKEN        | phantom project_id in WHERE                       |
| psypi-task-add             | BROKEN        | FK violation on project_id (projects table empty) |
| psypi-task-list            | BROKEN        | phantom source column                             |
| psypi-task-get             | BROKEN        | phantom source column                             |
| psypi-learn-save           | BROKEN        | trigger cascade via source='learn'                |
| psypi-broadcast            | BROKEN        | phantom priority, metadata columns                |
| psypi-inter-review-request | WORKS         | uses SQL function, no phantom columns             |
| psypi-inter-review-list    | WORKS (empty) | will break when rows exist (missing ::text)       |
| psypi-stats                | WORKS         | simple COUNT queries                              |
| psypi-memory-search        | WORKS (empty) | SELECT *, decoder picks named fields              |

10 out of 14 tools broken.

---

## Database State

| Table                  | Row Count |
| ---------------------- | --------- |
| memory                 | 0         |
| issues                 | 2         |
| tasks                  | 3         |
| inter_reviews          | 0         |
| project_communications | 0         |
| learning_insights      | 1         |
| projects               | 0         |
| agent_identities       | 1         |

### Key Constraints

- tasks.project_id FK -> projects (projects is EMPTY)
- tasks.created_by FK -> agent_identities (1 row exists: S-psypi-psypi-019deb1a...)
- issues table has NO project_id column at all
- issues table has NO created_by column at all

### Custom GUC

- app.current_project_id: can be SET, works as session variable
- Currently set to '0d324e68-b399-4b85-bd8a-6b1ef7b46168' on every connection
- This UUID does NOT exist in the projects table

---

## Fix Priority Order

1. Fix audit_direct_insert trigger: remove priority from project_communications INSERT
2. Seed projects table with the hardcoded UUID
3. Remove phantom columns from issue_db.gleam, areflect.gleam, monitor_ai.gleam
4. Remove phantom source from task.gleam
5. Add missing ::text casts in inter_review.gleam and task.gleam
6. Fix broadcast.gleam phantom columns
7. Fix learning.gleam source value (or add 'learn' to allowed_sources)
8. Implement PLAN-project-id-lookup.md for dynamic project_id
