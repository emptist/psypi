import gleam/option

pub type IdentityError {
  MissingSessionId
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
}

pub type IdentityContext {
  IdentityContext(
    is_idle: Bool,
    project: String,
    source: String,
    model: String,
    thinking_level: String,
    global: Bool,
    cwd: String,
  )
}

pub fn semantic_id(ctx: IdentityContext) -> Result(String, IdentityError) {
  let prefix = case ctx.is_idle {
    True -> "A"
    False -> "S"
  }

  let project = case ctx.global {
    True -> "G"
    False -> ctx.project
  }

  case ctx.model {
    "" -> Error(MissingSessionId)
    _ -> {
      let base =
        prefix
        <> "-"
        <> project
        <> "-"
        <> ctx.source
        <> "-"
        <> ctx.model

      case ctx.thinking_level {
        "" -> Ok(base)
        tl -> Ok(base <> "-" <> tl)
      }
    }
  }
}

pub fn resolved_identity(
  ctx: IdentityContext,
) -> Result(AgentIdentity, IdentityError) {
  case semantic_id(ctx) {
    Ok(id) ->
      Ok(
        AgentIdentity(
          id: id,
          project: option.Some(ctx.project),
          git_hash: option.None,
          machine_fingerprint: "",
          session_id: "",
          created_at: "",
          display_name: option.None,
          description: option.None,
          source: option.Some(ctx.source),
          model: option.Some(ctx.model),
          thinking_level: case ctx.thinking_level {
            "" -> option.None
            tl -> option.Some(tl)
          },
        ),
      )
    Error(e) -> Error(e)
  }
}

pub type AgentId {
  AgentId(String)
}

pub fn agent_id(ctx: IdentityContext) -> Result(AgentId, IdentityError) {
  case semantic_id(ctx) {
    Ok(id) -> Ok(AgentId(id))
    Error(e) -> Error(e)
  }
}

pub fn agent_id_from_string(s: String) -> AgentId {
  AgentId(s)
}

pub fn agent_id_to_string(id: AgentId) -> String {
  case id {
    AgentId(s) -> s
  }
}

pub type AgentIdentity {
  AgentIdentity(
    id: String,
    project: option.Option(String),
    git_hash: option.Option(String),
    machine_fingerprint: String,
    session_id: String,
    created_at: String,
    display_name: option.Option(String),
    description: option.Option(String),
    source: option.Option(String),
    model: option.Option(String),
    thinking_level: option.Option(String),
  )
}
