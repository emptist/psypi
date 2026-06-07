import db
import db_utils
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/option
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
  db_utils.decode_rows(rows, decoder, fn(e) { e })
}

pub fn read_soul_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT content FROM agent_souls WHERE id_prefix = 'A' AND is_active = true AND is_archived = false"
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
        <> "WHERE s.id_prefix = 'A' AND j.is_active = true AND j.is_archived = false "
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

/// Read key concepts that A-bot MUST understand to do its Check work correctly.
/// Only database semantics (is_archived, is_active) — these are field-level
/// meanings that A must not get wrong when reviewing S's code.
/// Other concepts A can ask S about via turn-based dialogue.
pub fn read_key_concepts_for_a() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT concept_key, term, definition, context, examples, anti_patterns, related_concepts "
        <> "FROM key_concept_definitions "
        <> "WHERE category = 'database' AND is_active = true AND is_archived = false "
        <> "ORDER BY concept_key"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("")
              rows ->
                rows
                |> decode_rows(concept_row_decoder())
                |> result.map(format_concepts)
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn concept_row_decoder() -> decode.Decoder(String) {
  use concept_key <- decode.field("concept_key", decode.string)
  use term <- decode.field("term", decode.string)
  use definition <- decode.field("definition", decode.string)
  use context <- decode.field("context", decode.optional(decode.string))
  use examples <- decode.field("examples", decode.optional(decode.string))
  use anti_patterns <- decode.field(
    "anti_patterns",
    decode.optional(decode.string),
  )
  use related <- decode.field(
    "related_concepts",
    decode.optional(decode.list(decode.string)),
  )
  let ctx = option.unwrap(context, "")
  let ex = option.unwrap(examples, "")
  let anti = option.unwrap(anti_patterns, "")
  let rel = case related {
    option.Some(r) -> string.join(r, ", ")
    option.None -> ""
  }
  let parts = [
    "### " <> term <> " (" <> concept_key <> ")",
    definition,
    case ctx {
      "" -> ""
      _ -> "**When/where**: " <> ctx
    },
    case ex {
      "" -> ""
      _ -> "**Correct usage**: " <> ex
    },
    case anti {
      "" -> ""
      _ -> "**Common mistakes**: " <> anti
    },
    case rel {
      "" -> ""
      _ -> "**Related**: " <> rel
    },
  ]
  decode.success(string.join(parts, "\n"))
}

fn format_concepts(lines: List(String)) -> String {
  string.join(lines, "\n\n")
}
