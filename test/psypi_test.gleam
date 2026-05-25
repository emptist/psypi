import a_context_utils
import agent_identity_types.{IdentityContext, MissingSessionId, semantic_id}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn generate_semantic_id_test() {
  semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: False,
    cwd: "",
  ))
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha"))

  semantic_id(IdentityContext(
    is_idle: True,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: False,
    cwd: "",
  ))
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha"))

  semantic_id(IdentityContext(
    is_idle: False,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: True,
    cwd: "",
  ))
  |> should.equal(Ok("G-S-non-project-openrouter-owl-alpha"))

  semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "",
    global: True,
    cwd: "",
  ))
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha"))

  semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: False,
    cwd: "",
  ))
  |> should.equal(Error(MissingSessionId))
}

pub fn generate_semantic_id_with_thinking_test() {
  semantic_id(IdentityContext(
    is_idle: True,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "high",
    global: False,
    cwd: "",
  ))
  |> should.equal(Ok("A-tools_ai-openrouter-owl-alpha-high"))

  semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "medium",
    global: False,
    cwd: "",
  ))
  |> should.equal(Ok("S-tools_ai-openrouter-owl-alpha-medium"))

  semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "owl-alpha",
    thinking_level: "high",
    global: True,
    cwd: "",
  ))
  |> should.equal(Ok("G-A-non-project-openrouter-owl-alpha-high"))
}

pub fn no_fallback_test() {
  semantic_id(IdentityContext(
    is_idle: False,
    project: "tools_ai",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: False,
    cwd: "",
  ))
  |> should.equal(Error(MissingSessionId))

  semantic_id(IdentityContext(
    is_idle: True,
    project: "non-project",
    source: "openrouter",
    model: "",
    thinking_level: "",
    global: True,
    cwd: "",
  ))
  |> should.equal(Error(MissingSessionId))
}

pub fn parse_context_window_valid_test() {
  a_context_utils.parse_context_window(
    "{\"tokens\":12345,\"contextWindow\":200000,\"percent\":6.17}",
  )
  |> should.equal(Ok(200000))
}

pub fn parse_context_window_null_tokens_test() {
  a_context_utils.parse_context_window(
    "{\"tokens\":null,\"contextWindow\":128000,\"percent\":null}",
  )
  |> should.equal(Ok(128000))
}

pub fn parse_context_window_missing_field_test() {
  a_context_utils.parse_context_window("{\"tokens\":12345}")
  |> should.be_error()
}

pub fn parse_context_window_invalid_json_test() {
  a_context_utils.parse_context_window("not json")
  |> should.be_error()
}
