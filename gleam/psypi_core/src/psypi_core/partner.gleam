// gleam/psypi_core/src/psypi_core/partner.gleam
// Permanent Partner - simplified and modular (< 50 lines)

// Session status
pub type Status {
  Alive
  Dead
  Pending
}

// FFI declarations
@external(javascript, "./partner_ffi.mjs", "create")
fn create_ffi(identity: String) -> String

@external(javascript, "./partner_ffi.mjs", "heartbeat")
fn heartbeat_ffi(session_id: String) -> String

// Public API: Create partner session
pub fn create(identity: String) -> String {
  create_ffi(identity)
}

// Public API: Send heartbeat  
pub fn heartbeat(session_id: String) -> String {
  heartbeat_ffi(session_id)
}
