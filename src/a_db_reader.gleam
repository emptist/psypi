import db
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/result
import gleam/string

pub fn db_error_to_string(e: db.DbError) -> String {
  case e {
    db.ConnectionError(msg) -> "DB connection: " <> msg
    db.QueryError(msg) -> "DB query: " <> msg
  }
}

pub fn decode_rows(
  rows: List(Dynamic),
  decoder: decode.Decoder(a),
) -> Result(List(a), String) {
  rows
  |> list.map(fn(row) {
    decode.run(row, decoder)
    |> result.map_error(fn(e) { "decode: " <> string.inspect(e) })
  })
  |> result.all
}

pub fn read_soul_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT content FROM agent_souls WHERE id_prefix = 'A' AND is_active = true"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] ->
                Error(
                  "No AutonomicBot soul found. Check: SELECT * FROM agent_souls WHERE id_prefix='A'",
                )
              [row, ..] ->
                case decode.run(row, content_decoder()) {
                  Ok(content) -> Ok(content)
                  Error(e) ->
                    Error("decode soul content: " <> string.inspect(e))
                }
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn content_decoder() -> decode.Decoder(String) {
  use content <- decode.field("content", decode.string)
  decode.success(content)
}

pub fn read_a_jobs_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT j.job, j.priority, j.category "
        <> "FROM agent_jobs j "
        <> "JOIN agent_souls s ON j.soul_id = s.id "
        <> "WHERE s.id_prefix = 'A' AND j.is_active = true "
        <> "ORDER BY j.priority ASC"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("  (no active jobs)")
              rows ->
                rows
                |> decode_rows(a_job_row_decoder())
                |> result.map(fn(lines) { string.join(lines, "\n") })
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn a_job_row_decoder() -> decode.Decoder(String) {
  use job <- decode.field("job", decode.string)
  use priority <- decode.field("priority", decode.int)
  use category <- decode.field("category", decode.string)
  decode.success("  " <> int.to_string(priority) <> ". [" <> category <> "] " <> job)
}

pub fn get_last_a_session_at() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql = "SELECT value FROM psypi_config WHERE key = 'last_a_session_at'"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("")
              [row, ..] -> {
                case decode.run(row, config_value_decoder()) {
                  Ok(v) -> Ok(v)
                  Error(_) -> Ok("")
                }
              }
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn config_value_decoder() -> decode.Decoder(String) {
  use value <- decode.field("value", decode.string)
  decode.success(value)
}
