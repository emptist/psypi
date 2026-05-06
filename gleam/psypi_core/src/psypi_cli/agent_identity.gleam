import gleam/javascript/promise
import psypi_cli/db
import psypi_cli/agent_identity_types.{AgentIdentity, type AgentIdentity, type IdentityError, ConnectionError, QueryError}
import psypi_cli/agent_identity_db.{insert_identity, fetch_identity_by_id, list_identities}
import psypi_cli/agent_identity_logic.{generate_semantic_id}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn get_resolved_identity(
  permanent: Bool,
  session_id: String,
  project: String,
  git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  db.with_connection(fn(conn) {
    let id = generate_semantic_id(permanent, source, project, session_id, model)
    
    promise.await(insert_identity(conn, id, project, git_hash, machine_fingerprint, source, session_id), fn(insert_result) {
      case insert_result {
        Ok(_) -> fetch_identity_by_id(conn, id)
        Error(e) -> promise.resolve(Error(e))
      }
    })
  }, db_error_to_identity_error)
}
