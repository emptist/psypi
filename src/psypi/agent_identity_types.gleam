import gleam/option

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
  )
}

pub type IdentityError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
}
