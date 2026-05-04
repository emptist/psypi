import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import psypi_cli/db

pub type Visit {
  Visit(
    id: String,
    agent_id: String,
    visited_at: String,
  )
}

pub type VisitError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn db_error_to_visit_error(e: db.DbError) -> VisitError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn visit_decoder() -> decode.Decoder(Visit) {
  use id <- decode.field("id", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use visited_at <- decode.field("visited_at", decode.string)
  decode.success(Visit(id:, agent_id:, visited_at:))
}

/// List recent visits
pub fn list(
  limit: Int,
) -> promise.Promise(Result(List(Visit), VisitError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, agent_id, visited_at::text 
      FROM visits 
      ORDER BY visited_at DESC 
      LIMIT $1
    "
    let params = [dynamic.int(limit)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_visit_error(e))
        Ok(result) -> {
          let visits = result.rows
            |> list.map(fn(row) { decode.run(row, visit_decoder()) })
            |> list.filter_map(fn(r) { r })
          Ok(visits)
        }
      }
    })
  }, db_error_to_visit_error)
}
