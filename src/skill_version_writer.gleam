import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/string

pub type SkillVersionError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
  NoIdReturned
}

fn db_error_to_version_error(e: db.DbError) -> SkillVersionError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn decode_error_to_version_error(e: List(decode.DecodeError)) -> SkillVersionError {
  DecodeError("decode: " <> string.inspect(e))
}

/// Save a new version of a skill. Deactivates the old version
/// and inserts a new row with the provided content.
/// Returns the new row's id (UUID as string) on success.
pub fn save_skill_version(
  name: String,
  content: String,
  version: String,
  change_summary: String,
  improved_by: String,
) -> promise.Promise(Result(String, SkillVersionError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT save_skill_version($1, $2::jsonb, $3, $4, $5) AS new_id"
    let params = [
      dynamic.string(name),
      dynamic.string(content),
      dynamic.string(version),
      dynamic.string(change_summary),
      dynamic.string(improved_by),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_version_error(e))
        Ok(result) ->
          case result.rows {
            [] -> Error(NoIdReturned)
            [row, ..] ->
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(e) -> Error(decode_error_to_version_error(e))
              }
          }
      }
    })
  }, db_error_to_version_error)
}

fn id_decoder() -> decode.Decoder(String) {
  use new_id <- decode.field("new_id", decode.string)
  decode.success(new_id)
}
