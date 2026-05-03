// context.gleam - Context & identity (~40 lines)
// Small + Pure = Resilience!

pub type ContextError {
  SessionError(String)
  IdentityError(String)
}

pub fn my_id() -> Result(String, ContextError) {
  Ok("S-psypi-psypi")
}

pub fn partner_id() -> Result(String, ContextError) {
  Ok("P-tencent/hy3-preview:free-psypi")
}

pub fn my_session_id() -> Result(String, ContextError) {
  Ok("019da0b2-0000-0000-0000-000000000000")
}

pub fn get_context(purpose: String) -> Result(String, ContextError) {
  Ok("Context for: " <> purpose)
}
