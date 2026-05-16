import gleeunit
import gleeunit/should
import agent_identity_logic
import agent_identity_types

pub fn main() {
  gleeunit.main()
}

pub fn generate_semantic_id_test() {
  // Test: Worker in project dir
  agent_identity_logic.generate_semantic_id(False, "tools_ai", "openrouter", "owl-alpha", "", False)
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha"))

  // Test: Monitor in project dir
  agent_identity_logic.generate_semantic_id(True, "tools_ai", "openrouter", "owl-alpha", "", False)
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha"))

  // Test: Worker in non-project dir (global)
  agent_identity_logic.generate_semantic_id(False, "non-project", "openrouter", "owl-alpha", "", True)
  |> should.equal(Ok("G-S-non-project-openrouter-owl-alpha"))

  // Test: Monitor in non-project dir (global)
  agent_identity_logic.generate_semantic_id(True, "non-project", "openrouter", "owl-alpha", "", True)
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha"))

  // Test: Missing model is error
  agent_identity_logic.generate_semantic_id(False, "tools_ai", "openrouter", "", "", False)
  |> should.equal(Error(agent_identity_types.MissingSessionId))
}

pub fn generate_semantic_id_with_thinking_test() {
  // Test: ID includes thinking_level when present
  agent_identity_logic.generate_semantic_id(True, "tools_ai", "openrouter", "owl-alpha", "high", False)
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha-high"))

  agent_identity_logic.generate_semantic_id(False, "tools_ai", "openrouter", "owl-alpha", "medium", False)
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha-medium"))

  // Test: Global + thinking_level
  agent_identity_logic.generate_semantic_id(True, "non-project", "openrouter", "owl-alpha", "high", True)
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha-high"))
}

pub fn no_fallback_test() {
  // Test: No fallback - empty model is always error
  agent_identity_logic.generate_semantic_id(False, "tools_ai", "openrouter", "", "", False)
  |> should.equal(Error(agent_identity_types.MissingSessionId))

  agent_identity_logic.generate_semantic_id(True, "non-project", "openrouter", "", "", True)
  |> should.equal(Error(agent_identity_types.MissingSessionId))
}