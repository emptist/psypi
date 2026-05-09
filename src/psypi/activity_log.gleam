import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi/db
import psypi/agent_identity_types.{type AgentId, agent_id_to_string}

pub type ActivityLog {
  ActivityLog(
    id: String,
    agent_id: String,
    activity: String,
    context: String, // JSON string
    git_hash: Option(String),
    git_branch: Option(String),
    environment: String,
    timestamp: String,
  )
}

pub type ActivityLoggingError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_log_error(e: db.DbError) -> ActivityLoggingError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Decoder for ActivityLog (corrected pattern!)
fn activity_log_decoder() -> decode.Decoder(ActivityLog) {
  use id <- decode.field("id", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use activity <- decode.field("activity", decode.string)
  use context <- decode.field("context", decode.string)
  use git_hash <- decode.field("git_hash", decode.optional(decode.string))
  use git_branch <- decode.field("git_branch", decode.optional(decode.string))
  use environment <- decode.field("environment", decode.string)
  use timestamp <- decode.field("timestamp", decode.string)
  decode.success(ActivityLog(id:, agent_id:, activity:, context:, git_hash:, git_branch:, environment:, timestamp:))
}

/// Log activity to database
pub fn log_activity(
  agent_id: AgentId,
  activity: String,
  context: String,
) -> promise.Promise(Result(String, ActivityLoggingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO activity_log (agent_id, activity, context, git_hash, git_branch, environment)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id
    "
    let params = [
      dynamic.string(agent_id_to_string(agent_id)),
      dynamic.string(activity),
      dynamic.string(context),
      dynamic.string(""), // git_hash - TODO
      dynamic.string(""), // git_branch - TODO
      dynamic.string("development"), // environment
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_log_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(QueryError("No ID returned"))
            [row, ..] -> {
              case decode.run(row, activity_log_decoder()) {
                Ok(log) -> Ok(log.id)
                Error(_) -> Error(DecodeError("Failed to decode activity log"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_log_error)
}

/// Get recent activity
pub fn get_recent_activity(
  agent_id: Option(String),
  limit: Int,
) -> promise.Promise(Result(List(ActivityLog), ActivityLoggingError)) {
  db.with_connection(fn(conn) {
    let sql = case agent_id {
      Some(_) -> "SELECT * FROM activity_log WHERE agent_id = $1 ORDER BY timestamp DESC LIMIT $2"
      None -> "SELECT * FROM activity_log ORDER BY timestamp DESC LIMIT $1"
    }

    let params = case agent_id {
      Some(id) -> [dynamic.string(id), dynamic.int(limit)]
      None -> [dynamic.int(limit)]
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_log_error(e))
        Ok(result) -> {
          let logs = result.rows
            |> list.map(fn(row) {
              case decode.run(row, activity_log_decoder()) {
                Ok(log) -> [log]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(logs)
        }
      }
    })
  }, db_error_to_log_error)
}
