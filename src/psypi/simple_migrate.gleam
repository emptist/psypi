import gleam/javascript/promise
import psypi/db

pub type MigrateError {
  ConnectionError(String)
  QueryError(String)
}

fn db_error_to_migrate_error(e: db.DbError) -> MigrateError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Run a simple migration SQL
pub fn run_sql(sql: String) -> promise.Promise(Result(Nil, MigrateError)) {
  db.with_connection(fn(conn) {
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_migrate_error(e))
        Ok(_) -> Ok(Nil)
      }
    })
  }, db_error_to_migrate_error)
}
