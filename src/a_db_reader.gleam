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

pub fn is_s_still_idle() -> promise.Promise(Result(Bool, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT COUNT(*) as cnt FROM agent_sessions "
        <> "WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok(True)
              [row, ..] -> {
                case decode.run(row, count_decoder()) {
                  Ok(cnt) -> Ok(cnt == 0)
                  Error(_) -> Ok(True)
                }
              }
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn count_decoder() -> decode.Decoder(Int) {
  use cnt <- decode.field("cnt", decode.int)
  decode.success(cnt)
}

pub fn read_soul_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT role, domain, responsibility FROM agent_souls WHERE id_prefix = 'A'"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            result.rows
            |> decode_rows(soul_responsibility_decoder())
            |> result.map(fn(entries) {
              case entries {
                [] -> Error("No AutonomicBot soul entries found")
                _ -> Ok(string.join(entries, "\n"))
              }
            })
            |> result.flatten
        }
      })
    },
    db_error_to_string,
  )
}

fn soul_responsibility_decoder() -> decode.Decoder(String) {
  use role <- decode.field("role", decode.string)
  use domain <- decode.field("domain", decode.string)
  use responsibility <- decode.field("responsibility", decode.string)
  decode.success("[" <> role <> " | " <> domain <> "] " <> responsibility)
}

pub fn read_project_state_from_db() -> promise.Promise(Result(String, String)) {
  let tasks_promise = read_active_tasks()
  let issues_promise = read_open_issues()
  promise.await(tasks_promise, fn(tasks_result) {
    let tasks_text = case tasks_result {
      Ok(t) -> t
      Error(_) -> "  (tasks unavailable)"
    }
    promise.await(issues_promise, fn(issues_result) {
      let issues_text = case issues_result {
        Ok(i) -> i
        Error(_) -> "  (issues unavailable)"
      }
      promise.resolve(Ok(
        "ACTIVE TASKS:\n" <> tasks_text <> "\n\nOPEN ISSUES:\n" <> issues_text,
      ))
    })
  })
}

fn read_active_tasks() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT id::text, title, status, priority, is_stuck "
        <> "FROM tasks WHERE status NOT IN ('COMPLETED','FAILED','FAKE_COMPLETE') "
        <> "ORDER BY is_stuck DESC, priority DESC, updated_at ASC LIMIT 10"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("  (none)")
              rows ->
                rows
                |> decode_rows(task_row_decoder())
                |> result.map(fn(lines) { string.join(lines, "\n") })
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn read_open_issues() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT id::text, title, severity "
        <> "FROM issues WHERE status NOT IN ('resolved','closed') "
        <> "ORDER BY created_at DESC LIMIT 10"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("  (none)")
              rows ->
                rows
                |> decode_rows(issue_row_decoder())
                |> result.map(fn(lines) { string.join(lines, "\n") })
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn task_row_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use status <- decode.field("status", decode.string)
  use priority <- decode.field("priority", decode.int)
  use is_stuck <- decode.field("is_stuck", decode.bool)
  let prefix = case is_stuck {
    True -> "[STUCK] "
    False -> ""
  }
  decode.success(
    "  - "
    <> prefix
    <> "["
    <> status
    <> " p"
    <> int.to_string(priority)
    <> "] "
    <> title
    <> " (id: "
    <> id
    <> ")",
  )
}

fn issue_row_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use severity <- decode.field("severity", decode.string)
  decode.success("  - [" <> severity <> "] " <> title <> " (id: " <> id <> ")")
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
      let sql = "SELECT value FROM config WHERE key = 'last_a_session_at'"
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
