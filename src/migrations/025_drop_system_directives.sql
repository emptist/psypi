-- Migration 025: Deprecate system_directives table
-- The system_directives table was an anti-pattern for A->S communication.
-- A communicates with S via sendMessage() — S is an LLM that reads natural language.
-- No database intermediary needed. The LLM is the protocol.
-- See: README.md "Lesson: The system_directives Anti-Pattern"

-- Drop dependent index first
DROP INDEX IF EXISTS idx_system_directives_agent_active;

-- Drop the table
DROP TABLE IF EXISTS system_directives;
