import gleam/option
import agent_identity_types.{type AgentId, type AgentIdentity, type IdentityError, AgentIdentity, agent_id}
import agent_identity_logic.{generate_semantic_id}
import pi_tool_call.{type PiToolCall, PiToolCall, raw_json, lit}

/// Get resolved agent identity - PURE function, no DB needed.
/// Computes the AgentIdentity from input parameters.
///
/// ID format: (A|S)-source-project-model[-thinking_level]
///
/// Model and thinking_level come from the live Pi context (ctx.model).
/// Model is the primary differentiator in the ID — it represents the
/// actual intelligence operating. Thinking level is appended when
/// non-empty to distinguish different reasoning modes of the same model.
pub fn get_resolved_identity(
  autonomous: Bool,
  project: String,
  source: String,
  model: String,
  thinking_level: String,
  global: Bool,
) -> Result(AgentIdentity, IdentityError) {
  case generate_semantic_id(autonomous, project, source, model, thinking_level, global) {
    Ok(id) -> Ok(AgentIdentity(
      id: id,
      project: option.Some(project),
      git_hash: option.None,
      machine_fingerprint: "",
      session_id: "",
      created_at: "",
      display_name: option.None,
      description: option.None,
      source: option.Some(source),
      model: option.Some(model),
      thinking_level: case thinking_level {
        "" -> option.None
        tl -> option.Some(tl)
      },
    ))
    Error(e) -> Error(e)
  }
}

/// Get agent ID - PURE function, no DB needed.
pub fn get_agent_id(
  autonomous: Bool,
  project: String,
  source: String,
  model: String,
  thinking_level: String,
  global: Bool,
) -> Result(AgentId, IdentityError) {
  case generate_semantic_id(autonomous, project, source, model, thinking_level, global) {
    Ok(id) -> Ok(agent_id(id))
    Error(e) -> Error(e)
  }
}

// -------------------------------------------------------------------
// Pi Tool Call definitions
// Each module that wants to expose a Pi tool defines a PiToolCall value.
// The generator collects these and composes them into extension.js.
// -------------------------------------------------------------------

/// Build the JS expression that extracts model info from ctx.model.
/// ctx.model is a live getter on ExtensionContext — always reflects the
/// current model even if the user changed it mid-session via /model or Ctrl+P.
/// Falls back to empty string when ctx.model is undefined.
fn ctx_model_id() -> String {
  "(ctx.model?.id || '')"
}

/// Extract provider from ctx.model.id (e.g., "openrouter" from "openrouter/owl-alpha").
/// Falls back to 'unknown' if model is unavailable.
fn ctx_provider() -> String {
  "(function(){ var m = ctx.model?.id || ''; var i = m.indexOf('/'); return i >= 0 ? m.substring(0, i) : 'unknown'; }())"
}

/// Extract model short name from ctx.model.id (e.g., "owl-alpha" from "openrouter/owl-alpha").
/// Falls back to full id if no slash found.


fn ctx_model_thinking() -> String {
  "(ctx.model?.thinkingLevel || '')"
}

/// Extract project name from ctx.cwd.
/// Checks if .git exists in the directory — if not, it's a non-project dir.
/// Uses the last path component as the project name when .git exists.
/// Falls back to 'non-project' when no .git is found or cwd is empty.
fn ctx_project_name() -> String {
  "(function(){ var cwd = ctx.cwd || ''; if(!cwd) return 'non-project'; var parts = cwd.split('/').filter(Boolean); var dir = parts.pop() || ''; try { require('fs').statSync(cwd + '/.git'); return dir; } catch(e) { return 'non-project'; } }())"
}

/// Returns 'true' if the project name is 'non-project' (no .git found),
/// 'false' otherwise. Used to set the global flag in the agent ID.
fn ctx_is_global() -> String {
  "(function(){ var cwd = ctx.cwd || ''; if(!cwd) return true; try { require('fs').statSync(cwd + '/.git'); return false; } catch(e) { return true; } }())"
}

/// Pi tool: psypi-somatic-id — get Somatic Worker ID (autonomous=false → S-)
///
/// ID format: S-psypi-psypi-<model_id>[-<thinking_level>]
///
/// Model comes from ctx.model.id (live). Thinking level is appended when
/// the model supports reasoning and a level is active.
///
/// Examples:
///   S-psypi-psypi-openrouter/owl-alpha
///   S-psypi-psypi-anthropic/claude-opus-4-5-high
pub fn somatic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-somatic-id",
    description: "Get Somatic Worker ID (S- prefix, prompt-driven). ID includes model and thinking level from live ctx.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("false"),
      // project derived from ctx.cwd — directory name when .git exists, else 'non-project'
      lit(ctx_project_name()),
      // provider from ctx.model.id — e.g., 'openrouter', 'lmstudio'
      lit(ctx_provider()),
      // model from ctx.model.id — e.g., 'openrouter/owl-alpha'
      lit(ctx_model_id()),
      // thinking_level from ctx.model.thinkingLevel — empty string when off/unavailable
      lit(ctx_model_thinking()),
      // global flag — true when no .git found (non-project dir), prepends G- to ID
      lit(ctx_is_global()),
    ],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-autonomic-id — get Autonomic Worker ID (autonomous=true → A-)
///
/// ID format: A-psypi-psypi-<model_id>[-<thinking_level>]
///
/// Same model source as somatic-id. The A/S prefix is the only difference.
pub fn autonomic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-id",
    description: "Get Autonomic Worker ID (A- prefix, event-driven). ID includes model and thinking level from live ctx.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("true"),
      // project derived from ctx.cwd — directory name when .git exists, else 'non-project'
      lit(ctx_project_name()),
      // provider from ctx.model.id — e.g., 'openrouter', 'lmstudio'
      lit(ctx_provider()),
      // model from ctx.model.id — e.g., 'openrouter/owl-alpha'
      lit(ctx_model_id()),
      // thinking_level from ctx.model.thinkingLevel — empty string when off/unavailable
      lit(ctx_model_thinking()),
      // global flag — true when no .git found (non-project dir), prepends G- to ID
      lit(ctx_is_global()),
    ],
    result_format: raw_json(),
  )
}
