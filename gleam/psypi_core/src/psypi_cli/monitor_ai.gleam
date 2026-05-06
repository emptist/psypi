import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/string
import psypi_cli/db

pub type MonitorError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_monitor_error(e: db.DbError) -> MonitorError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Main Monitor AI loop - runs in background (stub)
pub fn start_monitor_loop() -> promise.Promise(Result(Nil, MonitorError)) {
  check_system_health()
}

/// Check system health (DB, disk, builds)
pub fn check_system_health() -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT 1 as health"
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_monitor_error(e))
      }
    })
  }, db_error_to_monitor_error)
}

/// Housekeeping - auto-backup before edits!
pub fn housekeeping(agent_id: String) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO code_versions (file_path, content, saved_by, reason)
      VALUES ($1, $2, $3, $4)
    "
    let params = [
      dynamic.string("monitor_ai_auto_backup"),
      dynamic.string("test content"),
      dynamic.string(agent_id),
      dynamic.string("auto-backup"),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_monitor_error(e))
      }
    })
  }, db_error_to_monitor_error)
}

/// Decoder for context rows
fn context_row_decoder() -> decode.Decoder(String) {
  use type_ <- decode.field("type_", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(type_ <> ": " <> content <> "\n")
}

/// Prepare context for worker AI - HELPS ME WORK FASTER! 💡
pub fn prepare_context(agent_id: String) -> promise.Promise(Result(String, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 'learning' as type_, content, created_at::text 
      FROM memory 
      WHERE agent_id = $1 AND source = 'learn'
      UNION ALL
      SELECT 'backup' as type_, file_path as content, created_at::text
      FROM code_versions
      WHERE saved_by = $1
      ORDER BY created_at DESC
      LIMIT 10
    "
    let params = [dynamic.string(agent_id)]
    
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          let context = "Recent activity for " <> agent_id <> ":\n"
          let rows = result.rows
            |> list.map(fn(row) {
              case decode.run(row, context_row_decoder()) {
                Ok(text) -> text
                Error(_) -> ""
              }
            })
            |> string.join("")
          Ok(context <> rows)
        }
      }
    })
  }, db_error_to_monitor_error)
}
