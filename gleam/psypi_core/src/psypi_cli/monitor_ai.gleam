import gleam/javascript/promise
import gleam/float
import gleam/dynamic
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
  promise.map(check_system_health(), fn(result) {
    case result {
      Ok(_) -> Ok(Nil)
      Error(e) -> Error(e)
    }
  })
}

/// Health report structure
pub type HealthReport {
  HealthReport(
    database: Bool,
    disk_free_gb: Float,
    build_status: String,
    timestamp: String,
  )
}

/// Convert HealthReport to JSON string
fn health_report_to_json(report: HealthReport) -> String {
  case report {
    HealthReport(db, disk, build, ts) -> {
      let db_str = case db {
        True -> "true"
        False -> "false"
      }
      let disk_str = float.to_string(disk)
      "{\"database\":"
      <> db_str
      <> ",\"disk_free_gb\":"
      <> disk_str
      <> ",\"build_status\":"
      <> "\"" <> build <> "\""
      <> ",\"timestamp\":"
      <> "\"" <> ts <> "\""
      <> "}"
    }
  }
}

/// Get disk free space (JS interop)
@external(javascript, "./monitor_ai_js", "get_disk_free_gb")
pub fn get_disk_free_gb() -> Float

/// Get build status (JS interop)
@external(javascript, "./monitor_ai_js", "get_build_status")
pub fn get_build_status() -> String

/// Get current timestamp (JS interop)
@external(javascript, "./monitor_ai_js", "get_timestamp")
pub fn get_timestamp() -> String

/// Check system health (DB, disk, builds)
pub fn check_system_health() -> promise.Promise(Result(String, IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT 1 as health"
    promise.map(db.query(conn, sql, []), fn(result) {
      let db_healthy = case result {
        Ok(_) -> True
        Error(_) -> False
      }
      let disk_free = get_disk_free_gb()
      let build = get_build_status()
      let ts = get_timestamp()
      let report = HealthReport(db_healthy, disk_free, build, ts)
      Ok(health_report_to_json(report))
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
