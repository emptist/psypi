-- Migration: 027l_remaining_module_findings.sql
-- Add findings for command_listen, node_ffi, and db.gleam issues

INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact) VALUES
-- #271: command_listen bypasses A-bot debounce chain
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 271, 'medium', 'logic_error', 'command_listen',
 'command_listen bypasses A-bot debounce chain — directly calls LLM and sends to S with no DB record',
 'command_listen.on_autonomic_listen() calls call_monitor() (direct LLM call) and then pi_send_message() with "autonomic-wakeup" type. This completely bypasses the A-bot debounce/wakeup chain (hook_on_agent_end). No inter_review record is created, no debounce protection, no heartbeat check. The message goes directly from LLM to S with no tracking.',
 'command_listen.gleam:30 call_monitor(ctx, user_prompt, system_prompt); :38 pi_send_message(pi, "autonomic-wakeup", message, "persistent"); no call to a_orchestrator; no INSERT INTO inter_reviews; no debounce check',
 'Human-triggered A messages bypass all safety mechanisms. No audit trail. No debounce. Could flood S with messages if human types rapidly.'),

-- #272: node_ffi execute() shell injection via unsanitized commands
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 272, 'medium', 'security', 'node_ffi',
 'node_ffi execute() uses execSync with unsanitized shell commands — command injection risk',
 'node_ffi.mjs execute() passes cmd directly to execSync(cmd, ...). While callers like tool_commit.gleam use shell_escape(), other callers may not. execSync runs commands through a shell, making it vulnerable to injection if any part of the command comes from untrusted input.',
 'node_ffi.mjs:17 execSync(cmd, { encoding: "utf-8", timeout: timeout, stdio: ["pipe", "pipe", "pipe"] }); tool_commit.gleam:87 shell_escape(message); but pi_extension.gleam exec_sync has no escaping requirement in its type signature',
 'If any caller forgets to escape, arbitrary commands can be executed. The type system does not enforce sanitization.'),

-- #273: db.gleam with_connection ignores disconnect errors
('ca9e914c-cce6-4db4-b3b1-29779d8e1837', 273, 'low', 'error_handling', 'db',
 'db.gleam with_connection() ignores disconnect errors — potential connection leak',
 'with_connection() calls disconnect(conn) after the callback, but uses `let _ = disconnect(conn)` which discards the result. If disconnect fails, the connection is leaked. Over time this could exhaust the connection pool.',
 'db.gleam:82 let _ = disconnect(conn); disconnect returns Result(Nil, DbError) but the result is discarded',
 'Connection leak if disconnect fails. Over time could exhaust pool. Low severity because PostgreSQL connections auto-close on process exit.');

-- Update system_reviews status to in_progress
UPDATE system_reviews SET status = 'in_progress'
WHERE id = 'ca9e914c-cce6-4db4-b3b1-29779d8e1837';
