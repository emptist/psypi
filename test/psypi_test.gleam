import agent_identity_logic
import agent_identity_types.{IdentityContext, MissingSessionId}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn generate_semantic_id_test() {
  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: False,
  ))
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: True,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: False,
  ))
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: False,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: True,
  ))
  |> should.equal(Ok("G-S-non-project-openrouter-owl-alpha"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: True,
  ))
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: False,
  ))
  |> should.equal(Error(MissingSessionId))
}

pub fn generate_semantic_id_with_thinking_test() {
  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: True,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "high",
    global: False,
  ))
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha-high"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "medium",
    global: False,
  ))
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha-medium"))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "high",
    global: True,
  ))
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha-high"))
}

pub fn no_fallback_test() {
  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: False,
  ))
  |> should.equal(Error(MissingSessionId))

  agent_identity_logic.generate_semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: True,
  ))
  |> should.equal(Error(MissingSessionId))
}
