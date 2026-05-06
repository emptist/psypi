import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/string
import gleam/result
import gleam/option
import psypi_cli/db

pub type AgentIdentity {
  AgentIdentity(
    id: String,
    project: option.Option(String),
    git_hash: option.Option(String),
    machine_fingerprint: String,
    created_at: String, // ISO8601 string
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

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// THE ONLY WAY to get agent identity - Single source of truth!
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
    
    // Try to create identity (ON CONFLICT DO NOTHING)
    let insert_sql = "
      INSERT INTO agent_identities (id, project, git_hash, machine_fingerprint, source, session_id)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (id) DO NOTHING
    "
    
    let insert_params = [
      dynamic.string(id),
      dynamic.string(project),
      dynamic.string(git_hash),
      dynamic.string(machine_fingerprint),
      dynamic.string(source),
      dynamic.string(session_id)
    ]
    
    // Insert then fetch
    promise.map(db.query(conn, insert_sql, insert_params), fn(insert_result) {
      case insert_result {
        Ok(_) -> {
          // Fetch the identity (whether just inserted or already existed)
          fetch_identity_by_id(conn, id)
        }
        Error(e) -> Error(db_error_to_identity_error(e))
      }
    })
  }, db_error_to_identity_error)
}

/// Fetch identity by ID
fn fetch_identity_by_id(
  conn: db.Connection,
  id: String,
) -> Result(AgentIdentity, IdentityError) {
  let sql = "
    SELECT id, project, git_hash, machine_fingerprint, 
           created_at::text, display_name, description, source
    FROM agent_identities 
    WHERE id = $1
    LIMIT 1
  "
  
  let params = [dynamic.string(id)]
  
  case db.query(conn, sql, params) {
    Ok(result) -> {
      case result.rows {
        [row] -> {
          case decode.run(row, identity_decoder()) {
            Ok(identity) -> Ok(identity)
            Error(_) -> Error(QueryError("Failed to decode identity"))
          }
        }
        _ -> Error(NotFound("Identity not found: " <> id))
      }
    }
    Error(e) -> Error(db_error_to_identity_error(e))
  }
}

/// Generate semantic ID (same logic as TypeScript)
fn generate_semantic_id(
  permanent: Bool,
  source: String,
  project: String,
  session_id: String,
  model: String,
) -> String {
  let prefix = case permanent {
    True -> "P"
    False -> "S"
  }
  
  case permanent, model, project {
    // Permanent with model
    True, m, p if m != "" && p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> m <> "-" <> p
        sid -> prefix <> "-" <> m <> "-" <> p <> "-" <> sid
      }
    }
    True, m, _ if m != "" -> prefix <> "-" <> m
    True, _, p if p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> source <> "-" <> p
        sid -> prefix <> "-" <> source <> "-" <> p <> "-" <> sid
      }
    }
    True, _, _ -> prefix <> "-" <> source
    
    // Non-permanent
    False, _, p if p != "" -> {
      case session_id {
        "" -> prefix <> "-" <> source <> "-" <> p
        sid -> prefix <> "-" <> source <> "-" <> p <> "-" <> sid
      }
    }
    False, _, _ -> {
      let project_name = "unknown" // Would need cwd
      prefix <> "-" <> source <> "-" <> project_name <> "-????"
    }
  }
}

/// Decode database row to AgentIdentity
fn identity_decoder() -> decode.Decoder(AgentIdentity) {
  use id <- decode.field("id", decode.string)
  use project <- decode.optional_field("project", decode.string)
  use git_hash <- decode.optional_field("git_hash", decode.string)
  use machine_fingerprint <- decode.field("machine_fingerprint", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use display_name <- decode.optional_field("display_name", decode.string)
  use description <- decode.optional_field("description", decode.string)
  use source <- decode.optional_field("source", decode.string)
  
  decode.success(AgentIdentity(
    id:,
    project: option.from_result(project),
    git_hash: option.from_result(git_hash),
    machine_fingerprint:,
    created_at:,
    display_name: option.from_result(display_name),
    description: option.from_result(description),
    source: option.from_result(source),
  ))
}

/// List agent identities
pub fn list_identities(
  limit: Int,
) -> promise.Promise(Result(List(AgentIdentity), IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, project, git_hash, machine_fingerprint,
             created_at::text, display_name, description, source
      FROM agent_identities 
      ORDER BY created_at DESC 
      LIMIT $1
    "
    
    let params = [dynamic.int(limit)]
    
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Ok(result) -> {
          // Decode all rows
          let identities = result.rows
            |> list.map(fn(row) {
              decode.run(row, identity_decoder())
            })
            |> result.all
          
          case identities {
            Ok(ids) -> Ok(ids)
            Error(_) -> Error(QueryError("Failed to decode identities"))
          }
        }
        Error(e) -> Error(db_error_to_identity_error(e))
      }
    })
  }, db_error_to_identity_error)
}
