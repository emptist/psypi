# Implementation Plan – Core A‑S Workflow & System‑Review Database Fixes

## Overview
The pyspi engine must be able to (1) persist the timestamp of the last successful A‑bot session, (2) correctly handle the `idle_since` marker (treating the string `"0"` as a valid timestamp), and (3) isolate inter‑review results from commit messages while ensuring that all system‑review database objects are clean and consistent. Completing these tasks provides a reliable foundation for the basic A‑S dual‑workflow before any further self‑improvement work is attempted.

## Architecture Dependency Graph
```
Database schema
    │
    ├── API models/types
    │       │
    │       ├── API endpoints
    │       │       │
    │       │       └── Frontend API client
    │       │               │
    │       │               └── UI components
    │       │
    │       └── Validation logic
    │
    └── Seed data / migrations
```
Implementation order follows the dependency graph bottom‑up: build foundations first.

## Task List

### Phase 1 – Database Foundations
| # | Task | Acceptance Criteria | Dependencies | Estimated Scope |
|---|------|---------------------|--------------|-----------------|
| **T‑1** | Add `project_id` foreign‑key column to `tasks` table | Migration exists; after migration every row in `tasks` has a non‑NULL `project_id`. | None | M |
| **T‑2** | Add foreign‑key cascade from `inter_reviews.findings` → `findings` | Migration contains `ON DELETE CASCADE`; deleting a review removes related findings. | T‑1 | S |
| **T‑3** | Back‑fill missing `project_id` values in existing tasks | All tasks have a non‑NULL `project_id`; back‑fill runs in a single transaction. | T‑1 | XS |

### Phase 2 – Persistence of Session Metadata
| # | Task | Acceptance Criteria | Dependencies | Estimated Scope |
|---|------|---------------------|--------------|-----------------|
| **T‑4** | Persist `last_a_session_at` via `psypi_config` | Key exists with a valid timestamp string; subsequent read returns the same value. | Phase 1 migrations (ensure `psypi_config` table exists) | S |
| **T‑5** | Fix `idle_since` handling – treat `"0"` as a valid timestamp | `int.parse("0")` succeeds; debounce logic does not enter a reset loop. | T‑4 | XS |
| **T‑6** | Unify `now_ms` implementation | Only one `now_ms` external remains; `a_context_utils.current_time_ms` returns an `Int`. | Prior FFI cleanup (already completed) | S |

### Phase 3 – Inter‑Review Module & Findings
| # | Task | Acceptance Criteria | Dependencies | Estimated Scope |
|---|------|---------------------|--------------|-----------------|
| **T‑7** | Extract inter‑review logic into `src/inter_review.gleam` | Module compiles; `save` returns `Ok(Nil)` on success; uses `psypi_config` for related config. | Phase 1 (ensure `inter_reviews` table exists) | M |
| **T‑8** | Wire `inter_review.save` into `coordinate_when_idle` flow | Called after debounce verification; persists review before wake‑up; no commit alteration. | T‑7 | S |
| **T‑9** | Unit test for `inter_review.save` including finding creation | Test passes; inserted finding has non‑empty `module`, `severity`, `impact`; finding linked to review. | T‑7, Phase 1 | M |

### Phase 4 – System‑Review Findings Hygiene
| # | Task | Acceptance Criteria | Dependencies | Estimated Scope |
|---|------|---------------------|--------------|-----------------|
| **T‑10** | Audit all `system_review` findings for missing `module` or `impact` | Script lists findings with missing fields; no DB modifications. | Phase 3 (findings exist) | XS |
| **T‑11** | Add `category` column to `findings` if absent | Migration runs cleanly; all rows have non‑NULL `category` (default `"general"`). | T‑10 | S |
| **T‑12** | Generate a report of open findings grouped by severity | Report prints counts per severity; matches query result. | T‑11 | XS |

### Phase 5 – Monitoring, Human Review Integration & Final Checkpoints
| # | Task | Acceptance Criteria | Dependencies | Estimated Scope |
|---|------|---------------------|--------------|-----------------|
| **T‑13** | Create a “basic‑workflow‑alert” that fires when `last_a_session_at` missing > 5 min | Alert emitted via `psypi-broadcast-send` with priority `high`; message includes timestamp and elapsed minutes; only triggers when stale > 5 min. | T‑4 (timestamp persisted) and T‑6 (unified `now_ms`) | S |
| **T‑14** | Schedule a bi‑weekly system‑review meeting | Meeting created with `psypi-meeting-add`; topic “System‑Review Health”; attendees include all relevant agents; marked recurring every 14 days. | None | XS |
| **T‑15** | Verify end‑to‑end A‑S handover using a minimal integration test | Test flows: create task → commit → idle detection → verify `last_a_session_at` stored → persist inter‑review → ensure alert not raised during healthy run. | All previous tasks (1‑14) completed and verified | M |
| **T‑16** | Run the full checkpoint verification suite | All five checkpoints (1‑5) return success; suite exits with status 0; logs any failures. | Completion of tasks up to T‑15 | XS |

## Checkpoints
- **Checkpoint 1** – after Phase 1 (schema migrations).  
- **Checkpoint 2** – after Phase 2 (session metadata persistence).  
- **Checkpoint 3** – after Phase 3 (inter‑review module).  
- **Checkpoint 4** – after Phase 4 (findings hygiene).  
- **Checkpoint 5** – after Phase 5 (monitoring & final verification).  

All checkpoints must be green before moving to the next phase.

## Risks & Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Orphan foreign‑key rows after migrations | DB integrity broken → subsequent runs fail | Run migration validation (`psypi-stats-show`) and generate `psypi-findings` report (T‑10). |
| Duplicate `project_id` back‑fill causing conflicts | Tasks may be assigned wrong project | Use a single transaction when updating tasks; verify count before/after. |
| Debounce timer never fires due to incorrect `monitor_debounce_ms` | A‑bot stays idle indefinitely | Verify `psypi_config.get_debounce_ms` returns a sensible default; log the fetched value. |
| Findings missing `module` leads to vague reports | Hard to trace root cause | Enforce `psypi-finding-add` to require `module` argument; add CI check. |

## Verification
- **Checkpoint 1**: All migrations apply cleanly; DB schema passes audit.  
- **Checkpoint 2**: `last_a_session_at` is persisted and readable; `idle_since` handling works; `now_ms` unified.  
- **Checkpoint 3**: Inter‑review results stored independently of commits; no duplicate findings.  
- **Checkpoint 4**: All findings have complete metadata; report of open findings matches audit.  
- **Checkpoint 5**: Alert fires only on genuine missing `last_a_session_at`; meeting entry exists.

## Order, Prioritisation & Risks
- **P0**: T‑1, T‑2, T‑3, T‑4, T‑5, T‑6 – foundation of DB integrity & session metadata.  
- **P0**: T‑7, T‑8, T‑9 – isolate and store inter‑review results.  
- **P1**: T‑10, T‑11, T‑12 – clean up existing data issues.  
- **P1**: T‑13, T‑14, T‑15, T‑16 – monitoring, coordination, final verification.  

## Summary – Road‑Map to “pyspi works first”
1. Secure the foundation – DB migrations + schema hygiene (T‑1 → T‑3).  
2. Persist session markers – `last_a_session_at` & idle‑since fixes (T‑4 → T‑6).  
3. Isolate and store inter‑review results – new module & DB writes (T‑7 → T‑9).  
4. Clean existing data issues – findings metadata, foreign keys, back‑fill tasks (T‑10 → T‑12).  
5. Add monitoring & coordination – alerts for missing session, meeting schedule (T‑13 → T‑16).  

When the above tasks are completed and each checkpoint passes, the **pyspi engine will reliably execute the basic A‑S dual‑workflow**. At that point it can safely be used as the launchpad for further self‑improvement cycles (e.g., adding new skills, expanding review scopes, etc.).