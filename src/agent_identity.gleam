import agent_identity_types.{
  type AgentIdentity, type IdentityContext, type IdentityError,
  resolved_identity,
}
import pi_tool_call.{type PiToolCall, PiToolCall, raw_json, lit}

pub fn get_resolved_identity(
  ctx: IdentityContext,
) -> Result(AgentIdentity, IdentityError) {
  resolved_identity(ctx)
}

fn ctx_model_id() -> String {
  "(ctx.model?.id || '')"
}

fn ctx_provider() -> String {
  "(ctx.model?.provider || '')"
}

fn ctx_model_thinking() -> String {
  "(ctx.model?.thinkingLevel || '')"
}

fn ctx_project_name() -> String {
  "(function(){ var cwd = ctx.cwd || ''; if(!cwd) return 'non-project'; var parts = cwd.split('/').filter(Boolean); var dir = parts.pop() || ''; try { require('fs').statSync(cwd + '/.git'); return dir; } catch(e) { return 'non-project'; } }())"
}

fn ctx_is_global() -> String {
  "(function(){ var cwd = ctx.cwd || ''; if(!cwd) return true; try { require('fs').statSync(cwd + '/.git'); return false; } catch(e) { return true; } }())"
}

fn ctx_is_idle() -> String {
  "ctx.isIdle()"
}

pub fn somatic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-somatic-id",
    description: "Get Somatic Worker ID (S- prefix, prompt-driven). ID includes model and thinking level from live ctx.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("({ is_idle: " <> ctx_is_idle() <> ", project: " <> ctx_project_name() <> ", source: " <> ctx_provider() <> ", model: " <> ctx_model_id() <> ", thinking_level: " <> ctx_model_thinking() <> ", global: " <> ctx_is_global() <> " })"),
    ],
    result_format: raw_json(),
  )
}

pub fn autonomic_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-id",
    description: "Get Autonomic Worker ID (A- prefix, event-driven). ID includes model and thinking level from live ctx.",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("({ is_idle: " <> ctx_is_idle() <> ", project: " <> ctx_project_name() <> ", source: " <> ctx_provider() <> ", model: " <> ctx_model_id() <> ", thinking_level: " <> ctx_model_thinking() <> ", global: " <> ctx_is_global() <> " })"),
    ],
    result_format: raw_json(),
  )
}
