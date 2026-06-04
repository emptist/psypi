import db
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/string

pub type SoulVersionError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
  NoIdReturned
}

fn db_error_to_soul_error(e: db.DbError) -> SoulVersionError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn decode_error_to_soul_error(e: List(decode.DecodeError)) -> SoulVersionError {
  DecodeError("decode: " <> string.inspect(e))
}

/// Save a new version of an agent soul. Deactivates the old version
/// and inserts a new row with the provided content.
/// Returns the new row's id (UUID as string) on success.
pub fn save_soul_version(
  id_prefix: String,
  content: String,
) -> promise.Promise(Result(String, SoulVersionError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT save_soul_version($1, $2) AS new_id"
    let params = [dynamic.string(id_prefix), dynamic.string(content)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_soul_error(e))
        Ok(result) ->
          case result.rows {
            [] -> Error(NoIdReturned)
            [row, ..] ->
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(e) -> Error(decode_error_to_soul_error(e))
              }
          }
      }
    })
  }, db_error_to_soul_error)
}

/// Save a new version of an agent job. Deactivates the old version
/// and inserts a new row with the provided job text.
/// Returns the new row's id (UUID as string) on success.
pub fn save_job_version(
  soul_id: String,
  job_key: String,
  job: String,
  priority: Int,
  category: String,
) -> promise.Promise(Result(String, SoulVersionError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT save_job_version($1, $2, $3, $4, $5) AS new_id"
    let params = [
      dynamic.string(soul_id),
      dynamic.string(job_key),
      dynamic.string(job),
      dynamic.int(priority),
      dynamic.string(category),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_soul_error(e))
        Ok(result) ->
          case result.rows {
            [] -> Error(NoIdReturned)
            [row, ..] ->
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(e) -> Error(decode_error_to_soul_error(e))
              }
          }
      }
    })
  }, db_error_to_soul_error)
}

fn id_decoder() -> decode.Decoder(String) {
  use new_id <- decode.field("new_id", decode.string)
  decode.success(new_id)
}
