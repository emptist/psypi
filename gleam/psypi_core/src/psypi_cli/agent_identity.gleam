import gleam/javascript/promise
import psypi_cli/agent_identity_types.{type AgentIdentity, type IdentityError, ConnectionError}

pub fn get_resolved_identity(
  permanent: Bool,
  session_id: String,
  project: String,
  git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  // TODO: implement
  promise.resolve(Error(ConnectionError("Not implemented")))
}
