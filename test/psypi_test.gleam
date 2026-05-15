import gleeunit
import gleeunit/should
import agent_identity_logic
import agent_identity_types

pub fn main() {
  gleeunit.main()
}

pub fn generate_semantic_id_test() {
  // Test: Worker with session_id
  agent_identity_logic.generate_semantic_id(False, "psypi", "psypi", "abc123", "")
  |> should.equal(Ok("S-psypi-psypi-abc123"))

  // Test: Monitor with session_id
  agent_identity_logic.generate_semantic_id(True, "psypi", "psypi", "abc123", "")
  |> should.equal(Ok("A-psypi-psypi-abc123"))

  // Test: Missing session_id is error
  agent_identity_logic.generate_semantic_id(False, "psypi", "psypi", "", "")
  |> should.equal(Error(agent_identity_types.MissingSessionId))
}

pub fn generate_semantic_id_with_model_test() {
  // Test: ID includes model when present
  agent_identity_logic.generate_semantic_id(True, "psypi", "psypi", "abc123", "gemma3-tools")
  |> should.equal(Ok("A-gemma3-tools-psypi-abc123"))

  agent_identity_logic.generate_semantic_id(False, "psypi", "psypi", "abc123", "gemma3-tools")
  |> should.equal(Ok("S-psypi-psypi-abc123"))
}

pub fn no_fallback_test() {
  // Test: No fallback to "unknown" - empty session_id is always error
  agent_identity_logic.generate_semantic_id(False, "psypi", "", "", "")
  |> should.equal(Error(agent_identity_types.MissingSessionId))

  agent_identity_logic.generate_semantic_id(True, "", "", "", "")
  |> should.equal(Error(agent_identity_types.MissingSessionId))
}