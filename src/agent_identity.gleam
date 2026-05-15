import gleam/option
import agent_identity_types.{type AgentId, type AgentIdentity, type IdentityError, AgentIdentity, agent_id}
import agent_identity_logic.{generate_semantic_id}
import pi_tool_call.{type PiToolCall, PiToolCall, raw_json, lit}

/// Get resolved agent identity - PURE function, no DB needed.
/// Simply computes the AgentIdentity from input parameters.
/// Returns Error if session_id is missing (ID requires session context).
pub fn get_resolved_identity(
  autonomous: Bool,
  session_id: String,
  project: String,
  _git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> Result(AgentIdentity, IdentityError) {
  case generate_semantic_id(autonomous, source, project, session_id, model) {
    Ok(id) -> Ok(AgentIdentity(
      id: id,
      project: option.None,
      git_hash: option.None,
      machine_fingerprint: machine_fingerprint,
      session_id: session_id,
      created_at: "",
      display_name: option.None,
      description: option.None,
      source: option.None,
    ))
    Error(e) -> Error(e)
  }
}

/// Get agent ID - PURE function, no DB needed.
/// Returns Error if session_id is missing.
pub fn get_agent_id(
  autonomous: Bool,
  source: String,
  project: String,
  session_id: String,
  model: String,
) -> Result(AgentId, IdentityError) {
  case generate_semantic_id(autonomous, source, project, session_id, model) {
    Ok(id) -> Ok(agent_id(id))
    Error(e) -> Error(e)
  }
}

// -------------------------------------------------------------------
// Pi Tool Call definitions
// Each module that wants to expose a Pi tool defines a PiToolCall value.
// The generator collects these and composes them into extension.js.
// -------------------------------------------------------------------

/// Pi tool: psypi-somatic-id — get Somatic Worker ID (autonomous=false → S-)
/// session_id is obtained from Pi ctx's session_start hook
pub fn somatic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-somatic-id",
    description: "Get Somatic Worker ID (S- prefix, prompt-driven)",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("false"),
      lit("_sessionId"),
      lit("\"psypi\""),
      lit("\"\""),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
    ],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-autonomic-id — get Autonomic Worker ID (autonomous=true → A-)
/// Uses the SAME session_id as somatic-id, only the prefix differs (A- vs S-)
pub fn autonomic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-id",
    description: "Get Autonomic Worker ID (A- prefix, event-driven). Same session as somatic, only identity prefix differs.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("true"),
      lit("_sessionId"),
      lit("\"psypi\""),
      lit("\"\""),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
    ],
    result_format: raw_json(),
  )
}
