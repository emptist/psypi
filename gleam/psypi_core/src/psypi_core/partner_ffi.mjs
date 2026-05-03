// gleam/psypi_core/src/psypi_core/partner_ffi.mjs
// FFI bridge - simple and focused (< 30 lines)

import { createAgentSession, initTheme } from "@mariozechner/pi-coding-agent";

export function create(identity) {
  console.log("[FFI] Creating session for:", identity);
  // Placeholder - real Pi SDK call later
  return "session-" + identity;
}

export function heartbeat(session_id) {
  console.log("[FFI] Heartbeat for:", session_id);
  return "ok";
}
