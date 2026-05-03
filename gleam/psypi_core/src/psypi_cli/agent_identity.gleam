import gleam/option.{type Option, None, Some}

pub type AgentIdentity {
  AgentIdentity(
    id: String,
    project: Option(String),
    git_hash: Option(String),
    machine_fingerprint: Option(String),
    created_at: String,
    display_name: Option(String),
    description: Option(String),
    source: Option(String),
  )
}

pub type IdentityContext {
  IdentityContext(
    project: Option(String),
    git_hash: Option(String),
    machine_fingerprint: String,
    cwd: String,
    source: String,
    session_id: Option(String),
    permanent: Bool,
    model: Option(String),
  )
}

@external(javascript, "./agent_identity_ffi.mjs", "get_project_name")
fn get_project_name_ffi() -> Option(String)

@external(javascript, "./agent_identity_ffi.mjs", "get_git_hash")
fn get_git_hash_ffi() -> Option(String)

@external(javascript, "./agent_identity_ffi.mjs", "get_machine_fingerprint")
fn get_machine_fingerprint_ffi() -> String

@external(javascript, "./agent_identity_ffi.mjs", "get_source")
fn get_source_ffi() -> String

@external(javascript, "./agent_identity_ffi.mjs", "get_cwd")
fn get_cwd_ffi() -> String

@external(javascript, "./agent_identity_ffi.mjs", "resolve_inner_model")
fn resolve_inner_model_ffi() -> String

@external(javascript, "./agent_identity_ffi.mjs", "get_or_create_identity")
fn get_or_create_identity_ffi(
  id: String,
  project: Option(String),
  git_hash: Option(String),
  machine_fingerprint: String,
  source: String,
  session_id: Option(String),
) -> AgentIdentity

pub fn detect_context(
  permanent: Bool,
  model: Option(String),
  session_id: Option(String),
) -> IdentityContext {
  IdentityContext(
    project: get_project_name_ffi(),
    git_hash: get_git_hash_ffi(),
    machine_fingerprint: get_machine_fingerprint_ffi(),
    cwd: get_cwd_ffi(),
    source: get_source_ffi(),
    session_id: session_id,
    permanent: permanent,
    model: model,
  )
}

pub fn generate_semantic_id(ctx: IdentityContext) -> String {
  case ctx.permanent, ctx.model, ctx.project, ctx.session_id {
    True, Some(model), Some(project), Some(session_id) ->
      "P-" <> model <> "-" <> project <> "-" <> session_id
    True, Some(model), Some(project), None ->
      "P-" <> model <> "-" <> project
    True, Some(model), _, _ ->
      "P-" <> model
    True, _, Some(project), Some(session_id) ->
      "P-" <> ctx.source <> "-" <> project <> "-" <> session_id
    True, _, Some(project), None ->
      "P-" <> ctx.source <> "-" <> project
    True, _, _, _ ->
      "P-" <> ctx.source
    False, _, Some(project), Some(session_id) ->
      "S-" <> ctx.source <> "-" <> project <> "-" <> session_id
    False, _, Some(project), None ->
      "S-" <> ctx.source <> "-" <> project
    False, _, _, _ -> {
      let project_name = case ctx.cwd |> string.split("/") |> list.last {
        Some(name) -> name
        None -> "unknown"
      }
      "G-" <> ctx.source <> "-" <> project_name <> "-" <> ctx.machine_fingerprint
    }
  }
}

pub fn resolve(
  permanent: Bool,
  model: Option(String),
  session_id: Option(String),
) -> AgentIdentity {
  let ctx = detect_context(permanent, model, session_id)
  let id = generate_semantic_id(ctx)
  
  get_or_create_identity_ffi(
    id,
    ctx.project,
    ctx.git_hash,
    ctx.machine_fingerprint,
    ctx.source,
    ctx.session_id,
  )
}

pub fn get_resolved_identity(
  permanent: Bool,
  session_id: Option(String),
) -> AgentIdentity {
  let model = case permanent {
    True -> Some(resolve_inner_model_ffi())
    False -> None
  }
  
  resolve(permanent, model, session_id)
}
