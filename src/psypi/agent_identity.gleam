import gleam/option
import psypi/agent_identity_types.{type AgentId, type AgentIdentity, type IdentityError, AgentIdentity, agent_id}
import psypi/agent_identity_logic.{generate_semantic_id}
import psypi/pi_tool_call.{type PiToolCall, PiToolCall, raw_json, lit}

/// Get resolved agent identity - PURE function, no DB needed.
/// Simply computes the AgentIdentity from input parameters.
/// Returns Result for JS compatibility.
pub fn get_resolved_identity(
  permanent: Bool,
  session_id: String,
  project: String,
  _git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> Result(AgentIdentity, IdentityError) {
  let id = generate_semantic_id(permanent, source, project, session_id, model)
  Ok(AgentIdentity(
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
}

/// Get agent ID - PURE function, no DB needed.
/// Returns the computed ID string directly (not a Promise).
pub fn get_agent_id(
  permanent: Bool,
  source: String,
  project: String,
  session_id: String,
  model: String,
) -> AgentId {
  agent_id(generate_semantic_id(permanent, source, project, session_id, model))
}

// -------------------------------------------------------------------
// Pi Tool Call definitions
// Each module that wants to expose a Pi tool defines a PiToolCall value.
// The generator collects these and composes them into extension.js.
// -------------------------------------------------------------------

/// Pi tool: psypi-my-id — get current agent ID (permanent=false)
/// session_id is obtained from Pi ctx's session_start hook
pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get current agent ID",
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

/// Pi tool: psypi-monitor-id — get monitor/partner ID (permanent=true)
pub fn monitor_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-monitor-id",
    description: "Get monitor/partner ID (permanent identity)",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("true"),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
    ],
    result_format: raw_json(),
  )
}
