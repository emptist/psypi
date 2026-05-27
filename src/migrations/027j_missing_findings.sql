-- Missing findings from old review (SYSTEM-REVIEW-2026-05-26.md) not yet in DB
-- These were verified against source code before insertion

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES

-- Heartbeat / agent_sessions
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 244, 'critical', 'logic_error', 'a_db_reader', 'No code updates agent_sessions.last_heartbeat — is_s_still_idle always returns True',
 'a_db_reader.gleam:34 queries WHERE status = ''alive'' AND last_heartbeat > NOW() - INTERVAL ''5 minutes'' but no Gleam code ever UPDATEs last_heartbeat. All 19 sessions have last_heartbeat from 20+ days ago. The query always returns cnt=0, so is_s_still_idle() always returns Ok(True).',
 'a_db_reader.gleam:34 SELECT COUNT(*) FROM agent_sessions WHERE status=''alive'' AND last_heartbeat > NOW() - INTERVAL ''5 minutes''; grep -rh "UPDATE agent_sessions" src/*.gleam returns nothing; grep -rh "last_heartbeat" src/*.gleam only finds the SELECT',
 'A-bot can wake up while S is actively working. No guard against concurrent A+S execution.'),

-- Dual heartbeat columns
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 245, 'medium', 'design_flaw', 'a_db_reader', 'agent_sessions has TWO heartbeat columns: last_heartbeat and last_heartbeat_at',
 'agent_sessions table has both last_heartbeat and last_heartbeat_at (both timestamptz). Code only uses last_heartbeat. last_heartbeat_at is never referenced by any Gleam code. Likely added by an AI that did not check existing columns.',
 '\\d agent_sessions shows both columns; grep -rh "last_heartbeat_at" src/*.gleam returns nothing',
 'Confusion about which column is canonical. If wrong column is used for idle detection, results differ.'),

-- hook_on_tool_result fragile error detection
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 246, 'medium', 'design_flaw', 'hook_on_tool_result', 'hook_on_tool_result uses string.contains for error detection instead of JSON parsing',
 'on_tool_result detects errors by checking string.contains(result_json, "\"error\"") and similar patterns. This is fragile: legitimate tool output containing the word "error" triggers false positives. Missing actual error patterns causes false negatives.',
 'hook_on_tool_result.gleam:9-14 uses string.contains for 5 patterns; no json.decode or structured parsing',
 'False error reports from legitimate tool output, or missed errors from unrecognized patterns'),

-- a_orchestrator never writes inter-review response to DB
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 247, 'high', 'disconnected_systems', 'a_orchestrator', 'a_orchestrator.run_a_workflow never writes inter-review response to DB',
 'When A-bot generates a review response via call_monitor, the response is only sent via pi_send_message("autonomic-wakeup"). It is never written to inter_reviews table. The review response exists only in the Pi message queue, not in the database.',
 'a_orchestrator.gleam: full file — no INSERT INTO inter_reviews; only pi_send_message(pi, "autonomic-wakeup", response, "persistent")',
 'Inter-review responses are ephemeral. If Pi message queue is lost, review data is lost. No audit trail.'),

-- set_model race condition
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 248, 'medium', 'logic_error', 'monitor', 'monitor.set_model blanket reset race condition',
 'set_model() does UPDATE provider_api_keys SET status = ''not_used'' (resets ALL keys), then sets one key to ''in_use''. Between the two UPDATEs, all keys are temporarily ''not_used''. Concurrent calls could leave zero keys active.',
 'monitor.gleam:104 UPDATE provider_api_keys SET status = ''not_used''; then line 113-115 UPDATE ... SET status = ''in_use'' WHERE provider = $1',
 'Temporary window where no API key is active. Concurrent set_model calls could corrupt state.'),

-- get_config FFI returns JS null/string not Gleam Option
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 249, 'critical', 'ffi_mismatch', 'pi_extension_ffi', 'get_config FFI returns JS null/string which never matches Gleam None/Some constructors',
 'pi_extension_ffi.mjs get_config returns null when key not found, or the raw string value when found. Gleam expects Option(String): None or Some(string). JS null does not equal Gleam None, and JS string does not equal Gleam Some(string). The Some branch in hook_on_agent_end is NEVER reached.',
 'pi_extension_ffi.mjs: return row ? row.value : null; hook_on_agent_end.gleam uses case get_config(...) { Some(val) -> ... None -> ... } but Some is never matched',
 'idle_since is always re-recorded as now(). Debounce never fires. A-bot wakeup is completely broken.'),

-- semantic_id uses is_idle for A/S prefix
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 250, 'high', 'logic_error', 'agent_identity', 'semantic_id uses is_idle (momentary state) for A/S prefix (permanent identity)',
 'psypi-my-id tool determines A or S prefix by calling ctx_is_idle(ctx). When S is idle between turns, calling psypi-my-id returns an A-prefixed identity. Wrong soul loaded, wrong jobs fetched.',
 'agent_identity.gleam: semantic_id() calls ctx_is_idle(ctx) to determine prefix; if idle, returns "A-" prefix',
 'When S is momentarily idle, it gets A-prefixed identity. Wrong soul loaded, wrong jobs fetched, wrong behavior.'),

-- compose() called instead of compose_within_budget()
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 251, 'high', 'logic_error', 'a_orchestrator', 'compose() called instead of compose_within_budget() — token budget system unused',
 'a_orchestrator.gleam:66 calls compose(a_prompt_builder.build_system_prompt(...)) which concatenates all prompt parts without limit. compose_within_budget() exists in system_prompt_types.gleam and respects token limits but is never called.',
 'a_orchestrator.gleam:66 compose(...); system_prompt_types.gleam has compose_within_budget() that truncates to fit context window',
 'A-bot system prompt may exceed context window, causing LLM failures. Token budget system exists but is never used.'),

-- hook_on_tool_call only handles "edit" tool
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 252, 'medium', 'design_flaw', 'hook_on_tool_call', 'hook_on_tool_call only handles "edit" tool — all other tools ignored',
 'hook_on_tool_call.gleam only processes tool calls where tool_name == "edit". All other tool calls pass through without any monitoring or recording.',
 'hook_on_tool_call.gleam: checks if tool_name == "edit" then records; all other tools silently pass through',
 'No monitoring of non-edit tool calls. No error recording for failed tool calls except edit.'),

-- No connection pooling
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 253, 'medium', 'performance', 'db', 'No connection pooling — every query creates and destroys a connection',
 'db.gleam with_connection creates a new pg.Client.connect() for every query and closes it after. No connection pool. Under load (multiple concurrent tool calls), this creates many short-lived connections.',
 'db.gleam: with_connection calls pg.Client.connect() then pg.Client.close() for every query',
 'Connection overhead on every query. Under concurrent load, connection exhaustion or slowdown.'),

-- Migration system has no tracking table
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 254, 'medium', 'design_flaw', 'simple_migrate', 'Migration system has no tracking table — cannot determine which migrations have run',
 'simple_migrate.gleam reads all .sql files from src/migrations/ and runs them in order. But there is no migrations tracking table to record which migrations have already been applied. Running migrations twice could cause errors (duplicate tables, constraint violations).',
 'simple_migrate.gleam: reads and executes all .sql files; no CREATE TABLE migrations_applied or similar tracking',
 'Cannot determine current schema version. Re-running migrations may fail or cause duplicate data. No rollback capability.'),

-- tool_consult is a stub
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 255, 'medium', 'dead_code', 'monitor_ai', 'tool_consult is a stub — returns hardcoded message, no actual A-bot consultation',
 'monitor_ai.gleam tool_consult() returns "Consultation feature not yet implemented. Please use the psypi-consult tool for A-bot queries." It does not call any A-bot function or query any data.',
 'monitor_ai.gleam: tool_conslect returns hardcoded string; no call_monitor, no DB query, no A-bot interaction',
 'Consultation tool is non-functional. Agents that try to consult A-bot get a placeholder response.'),

-- psypi-my-id missing project and global fields
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 256, 'high', 'missing_params', 'agent_identity', 'psypi-my-id missing project and global fields in generated JS object',
 'agent_identity.gleam builds IdentityContext with lit() but omits project and global fields. semantic_id() reads ctx.project which becomes undefined in JS, stringifying to "undefined". Semantic ID becomes "S-undefined-anthropic-claude-3.5-sonnet" instead of "S-psypi-anthropic-...".',
 'agent_identity.gleam: lit() expression does not include project or global fields; compiled JS shows ctx.project is undefined',
 'Semantic IDs contain "undefined" instead of project name. G-prefix never used. Identity system broken.'),

-- _configStore race condition in extension.js
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 257, 'low', 'logic_error', 'pi_extension_ffi', '_configStore in-memory cache has race condition with concurrent access',
 'pi_extension_ffi.mjs uses a module-level _configStore object as in-memory cache. Multiple async operations can read/write _configStore concurrently. get_config reads from _configStore first, then DB. set_config writes to DB then updates _configStore. Between DB write and cache update, stale values may be read.',
 'pi_extension_ffi.mjs: let _configStore = {}; get_config checks _configStore first; set_config updates DB then _configStore',
 'Under concurrent access, stale config values may be used. Dual store (DB + in-memory) without synchronization.'),

-- inter-review commit flow permanently stuck
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 258, 'high', 'disconnected_systems', 'inter_review', 'Inter-review commit flow is permanently stuck — missing git add before git commit',
 'The inter-review flow calls tool_commit.gleam which runs git commit but does not run git add first. Without git add, untracked files are not committed. The commit may succeed but with empty diff, or fail if no staged changes exist.',
 'tool_commit.gleam: exec_sync("git commit ...") without prior git add; inter_review flow never calls git add',
 'Inter-review code changes are never actually committed. Review feedback is generated but code is not saved.'),

-- a_db_reader is_s_still_idle counts ALL sessions not just S sessions
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 259, 'high', 'logic_error', 'a_db_reader', 'is_s_still_idle counts ALL alive sessions, not just S-bot sessions',
 'a_db_reader.gleam:34 SELECT COUNT(*) FROM agent_sessions WHERE status = ''alive'' AND last_heartbeat > NOW() - INTERVAL ''5 minutes''. This counts ALL alive sessions including A-bot sessions. If A-bot has an active session, is_s_still_idle returns False even when S is idle.',
 'a_db_reader.gleam:34 no filter on agent prefix or role; counts all sessions with status=alive',
 'A-bot may think S is busy when only A-bot itself has an active session. Incorrect idle detection.');

UPDATE system_reviews SET current_state = 'coverage_gap_filled', updated_at = now()
WHERE id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';
