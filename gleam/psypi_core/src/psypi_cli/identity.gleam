import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import psypi_cli/db

pub type Identity {
  Identity(
    id: String,
    agent_type: String,
  )
}

pub type IdentityError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn identity_decoder() -> decode.Decoder(Identity) {
  use id <- decode.field("id", decode.string)
  use agent_type <- decode.field("agent_type", decode.string)
  decode.success(Identity(id:, agent_type:))
}

/// Get current session identity
pub fn get_current(session_id: String) -> promise.Promise(Result(Identity, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, agent_type 
      FROM agent_identities 
      WHERE session_id = $1 
      LIMIT 1
    "
    let params = [dynamic.string(session_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_identity_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(NotFound("Identity not found"))
            [row, ..] -> {
              case decode.run(row, identity_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(QueryError("Failed to decode identity"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_identity_error)
}

/// Get partner identity
pub fn get_partner() -> promise.Promise(Result(Identity, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, agent_type 
      FROM agent_identities 
      WHERE id LIKE 'P-%' 
      ORDER BY created_at DESC
      LIMIT 1
    "
    let params: List(dynamic.Dynamic) = []

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_identity_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(NotFound("Partner identity not found"))
            [row, ..] -> {
              case decode.run(row, identity_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(QueryError("Failed to decode partner identity"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_identity_error)
}
