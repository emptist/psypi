import gleam/javascript/promise
import gleam/list
import psypi_cli/db
import psypi_cli/agent_identity_types.{type AgentIdentity, type IdentityError, ConnectionError}

pub fn insert_identity(
  conn: db.Connection,
  id: String,
  project: String,
  git_hash: String,
  machine_fingerprint: String,
  source: String,
  session_id: String,
) -> promise.Promise(Result(Nil, IdentityError)) {
  promise.resolve(Ok(Nil))
}

pub fn fetch_identity_by_id(
  conn: db.Connection,
  id: String,
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  promise.resolve(Error(ConnectionError("Not implemented")))
}

pub fn list_identities(
  conn: db.Connection,
  limit: Int,
) -> promise.Promise(Result(List(AgentIdentity), IdentityError)) {
  promise.resolve(Ok([]))
}
