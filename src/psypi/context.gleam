// context.gleam - Context & identity (~40 lines)
// Small + Pure = Resilience!

pub fn my_id() -> Result(String, String) {
  Ok("S-psypi-psypi")
}

pub fn monitor_id() -> Result(String, String) {
  Ok("P-anthropic/claude-3.5-sonnet-psypi")
}

pub fn my_session_id() -> Result(String, String) {
  Ok("019da0b2-0000-0000-0000-000000000000")
}

pub fn get_context(purpose: String) -> Result(String, String) {
  Ok("Context for: " <> purpose)
}
