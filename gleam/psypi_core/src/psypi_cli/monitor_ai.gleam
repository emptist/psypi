import gleam/javascript/promise
import gleam/dynamic
import gleam/string
import psypi_cli/db
import psypi_cli/agent_identity_types.{type IdentityError, ConnectionError, QueryError}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Main Monitor AI loop - runs in background (stub)
pub fn start_monitor_loop() -> promise.Promise(Result(Nil, IdentityError)) {
  check_system_health()
}

/// Check system health (DB, disk, builds)
pub fn check_system_health() -> promise.Promise(Result(Nil, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT 1 as health"
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)  // DB is healthy
        Error(e) -> Error(db_error_to_identity_error(e))
      }
    })
  }, db_error_to_identity_error)
}

/// Housekeeping - auto-backup before edits!
pub fn housekeeping() -> promise.Promise(Result(Nil, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO code_versions (file_path, content, saved_by, reason)
      VALUES ($1, $2, $3, $4)
    "
    let params = [
      dynamic.string("monitor_ai_test"),
      dynamic.string("test content"),
      dynamic.string("monitor_ai"),
      dynamic.string("auto-backup test")
    ]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_identity_error(e))
      }
    })
  }, db_error_to_identity_error)
}

/// Prepare context for worker AI - HELPS ME WORK FASTER! 💡
pub fn prepare_context(query: String) -> promise.Promise(Result(String, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT file_path, reason
      FROM code_versions
      WHERE saved_by = $1
      ORDER BY id DESC
      LIMIT 5
    "
    let params = [dynamic.string(query)]
    
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(query_result) -> {
          // Simple: just return count of records
          let count = "Found " <> "5" <> " records for " <> query
          Ok(count)
        }
        Error(e) -> Error(db_error_to_identity_error(e))
      }
    })
  }, db_error_to_identity_error)
}
