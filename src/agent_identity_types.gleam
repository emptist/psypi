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
  )
}

/// Lightweight wrapper for agent ID - use this instead of String
pub type AgentId {
  AgentId(String)
}

/// Helper to create AgentId from String
pub fn agent_id(s: String) -> AgentId {
  AgentId(s)
}

/// Extract String from AgentId
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
