import gleam/javascript/promise
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
  // TODO: Implement real background loop
  // For now, just check system health
  check_system_health()
}

/// Check system health (DB, disk, builds)
fn check_system_health() -> promise.Promise(Result(Nil, IdentityError)) {
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
