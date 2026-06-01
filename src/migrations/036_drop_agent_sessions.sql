-- Drop agent_sessions table — dead infrastructure
-- No Gleam code writes to or reads from this table.
-- The is_s_still_idle() function that queried it was already removed.
-- Idle detection uses ctx_is_idle(ctx) from Pi runtime, which is the correct source of truth.

DROP TABLE IF EXISTS agent_sessions;
