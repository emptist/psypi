import gleam/dynamic
import gleam/javascript/promise
import gleam/list
import db

pub type QueryResult {
  QueryResult(
    rows: List(dynamic.Dynamic),
    row_count: Int,
  )
}

pub type QueryError {
  ConnectionError(String)
  QueryError(String)
}

fn db_error_to_query_error(e: db.DbError) -> QueryError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Execute a query and return results
pub fn execute(
  sql: String,
  params: List(dynamic.Dynamic),
) -> promise.Promise(Result(QueryResult, QueryError)) {
  db.with_connection(fn(conn) {
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_query_error(e))
        Ok(result) -> {
          let row_count = list.length(result.rows)
          Ok(QueryResult(rows: result.rows, row_count: row_count))
        }
      }
    })
  }, db_error_to_query_error)
}
