import gleam/dynamic
import gleam/javascript/promise
import gleam/result
import gleam/option
import gleam/list
import gleam/string
import gleam/dynamic/decode
import db
import agent_identity_types.{AgentIdentity, type AgentIdentity, type IdentityError, ConnectionError, QueryError, NotFound}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn insert_identity(
  conn: db.Connection,
  id: String,
  project: String,
  git_hash: String,
  machine_fingerprint: String,
  source: String,
  session_id: String,
  model: String,
  thinking_level: String,
) -> promise.Promise(Result(Nil, IdentityError)) {
  let insert_sql = "
    INSERT INTO agent_identities (id, project, git_hash, machine_fingerprint, source, session_id, model, thinking_level)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    ON CONFLICT (id) DO UPDATE SET
      model = EXCLUDED.model,
      thinking_level = EXCLUDED.thinking_level,
      updated_at = NOW()
  "
  
  let params = [
    dynamic.string(id),
    dynamic.string(project),
    dynamic.string(git_hash),
    dynamic.string(machine_fingerprint),
    dynamic.string(source),
    dynamic.string(session_id),
    dynamic.string(model),
    dynamic.string(thinking_level)
  ]
  
  promise.map(db.query(conn, insert_sql, params), fn(query_result) {
    case query_result {
      Ok(_) -> Ok(Nil)
      Error(e) -> Error(db_error_to_identity_error(e))
    }
  })
}

pub fn fetch_identity_by_id(
  conn: db.Connection,
  id: String,
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  let sql = "
    SELECT id, 
           COALESCE(project, '') as project, 
           COALESCE(git_hash, '') as git_hash, 
           machine_fingerprint, 
           session_id, 
           created_at::text as created_at, 
           COALESCE(display_name, '') as display_name, 
           COALESCE(description, '') as description, 
           COALESCE(source, '') as source,
           COALESCE(model, '') as model,
           COALESCE(thinking_level, '') as thinking_level
    FROM agent_identities 
    WHERE id = $1
    LIMIT 1
  "
  
  let params = [dynamic.string(id)]
  
  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
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
  })
}

fn identity_decoder() -> decode.Decoder(AgentIdentity) {
  use id <- decode.field("id", decode.string)
  use project <- decode.field("project", decode.string)
  use git_hash <- decode.field("git_hash", decode.string)
  use machine_fingerprint <- decode.field("machine_fingerprint", decode.string)
  use session_id <- decode.field("session_id", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use display_name <- decode.field("display_name", decode.string)
  use description <- decode.field("description", decode.string)
  use source <- decode.field("source", decode.string)
  use model <- decode.field("model", decode.string)
  use thinking_level <- decode.field("thinking_level", decode.string)

  decode.success(AgentIdentity(
    id:,
    project: string_to_option(project),
    git_hash: string_to_option(git_hash),
    machine_fingerprint:,
    session_id:,
    created_at:,
    display_name: string_to_option(display_name),
    description: string_to_option(description),
    source: string_to_option(source),
    model: string_to_option(model),
    thinking_level: string_to_option(thinking_level),
  ))
}

fn string_to_option(s: String) -> option.Option(String) {
  case string.is_empty(s) {
    True -> option.None
    False -> option.Some(s)
  }
}

pub fn list_identities(
  conn: db.Connection,
  limit: Int,
) -> promise.Promise(Result(List(AgentIdentity), IdentityError)) {
  let sql = "
      SELECT id, 
             COALESCE(project, '') as project, 
             COALESCE(git_hash, '') as git_hash, 
             machine_fingerprint, 
             session_id, 
             created_at::text as created_at, 
             COALESCE(display_name, '') as display_name, 
             COALESCE(description, '') as description, 
             COALESCE(source, '') as source,
             COALESCE(model, '') as model,
             COALESCE(thinking_level, '') as thinking_level
      FROM agent_identities 
      ORDER BY created_at DESC 
      LIMIT $1
    "
    
  let params = [dynamic.int(limit)]
    
  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Ok(result) -> {
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
}
