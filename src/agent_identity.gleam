// agent_identity.gleam — Agent identity resolution
//
// Resolves the current agent's identity (S-bot or A-bot) from context.
// Project detection and filesystem checks are done in Gleam, not in
// hand-written JS strings.

import agent_identity_types.{
  type AgentIdentity, type IdentityContext, type IdentityError,
  resolved_identity,
}
import gleam/list
import gleam/string
import pi_tool_call.{type PiToolCall, PiToolCall, lit, raw_json}

/// Resolve project name from cwd by taking the last path component
fn resolve_project(cwd: String) -> String {
  case cwd {
    "" -> "non-project"
    _ -> {
      let parts = string.split(cwd, "/") |> list.filter(fn(s) { s != "" })
      case list.last(parts) {
        Ok(dir) -> dir
        Error(_) -> "non-project"
      }
    }
  }
}

/// Check if cwd is a project directory (has .git subdirectory)
@external(javascript, "./agent_identity_ffi.mjs", "check_git_exists")
fn check_git_exists(cwd: String) -> Bool

/// Get the resolved agent identity from context
pub fn get_resolved_identity(
  ctx: IdentityContext,
) -> Result(AgentIdentity, IdentityError) {
  let project = resolve_project(ctx.cwd)
  let global = case check_git_exists(ctx.cwd) {
    True -> False
    False -> True
  }
  let ctx_with_project = agent_identity_types.IdentityContext(
    is_idle: ctx.is_idle,
    project: project,
    source: ctx.source,
    model: ctx.model,
    thinking_level: ctx.thinking_level,
    global: global,
    cwd: ctx.cwd,
  )
  resolved_identity(ctx_with_project)
}

/// Pi tool: psypi-my-id — get the calling agent's ID
pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get the calling agent's ID. Returns S- prefix when called by the Somatic Agentbot (prompt-driven), A- prefix when called by the Autonomic Agentbot (event-driven). ID includes model and thinking level from live ctx.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit(
        "({ is_idle: ctx.isIdle(), source: (ctx.model?.provider || ''), "
        <> "model: (ctx.model?.id || ''), "
        <> "thinking_level: (ctx.model?.thinkingLevel || ''), "
        <> "cwd: (ctx.cwd || '') })",
      ),
    ],
    result_format: raw_json(),
  )
}
