// worker_coordination.gleam — A-worker idle detection & wake-up messaging
//
// Detects when S-worker is idle and sends a [Monitor] wake-up prompt.

import gleam/javascript/promise
import db

pub type CoordinationError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_coord_error(e: db.DbError) -> CoordinationError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Check if there is outstanding work (open issues, pending tasks)
pub fn has_outstanding_work() -> promise.Promise(Result(Bool, CoordinationError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT
        (SELECT COUNT(*)::INT FROM issues WHERE status = 'open') as open_issues,
        (SELECT COUNT(*)::INT FROM tasks WHERE status = 'pending') as pending_tasks
    "
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_coord_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [_row, ..] -> {
              Ok(True)
            }
            _ -> Ok(False)
          }
        }
      }
    })
  }, db_error_to_coord_error)
}

/// Build the wake-up message content
pub fn build_wake_message() -> promise.Promise(Result(String, CoordinationError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT
        (SELECT COUNT(*)::INT FROM issues WHERE status = 'open') as open_issues,
        (SELECT COUNT(*)::INT FROM tasks WHERE status = 'pending') as pending_tasks,
        (SELECT COUNT(*)::INT FROM tasks WHERE status = 'FAILED') as failed_tasks
    "
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_coord_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [_row, ..] -> {
              Ok("[Monitor] Outstanding work detected. Check psypi-issues and psypi-tasks for details.")
            }
            _ -> Ok("[Monitor] System idle. No outstanding work.")
          }
        }
      }
    })
  }, db_error_to_coord_error)
}
