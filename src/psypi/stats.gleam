import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/int
import psypi/db.{type DbError, type Connection, with_connection}
import psypi/pi_tool_call.{type PiToolCall, PiToolCall, custom_js}

pub type Stats {
  Stats(tasks: Int, issues: Int, skills: Int, meetings: Int)
}

pub fn stats() -> promise.Promise(Result(Stats, DbError)) {
  with_connection(
    fn(conn: Connection) {
      let sql = "
        SELECT 
          (SELECT COUNT(*) FROM tasks) as tasks,
          (SELECT COUNT(*) FROM issues) as issues,
          (SELECT COUNT(*) FROM skills) as skills,
          (SELECT COUNT(*) FROM meetings) as meetings
      "
      promise.map(db.query(conn, sql, []), fn(result) {
        case result {
          Ok(query_result) -> {
            case query_result.rows {
              [row] -> {
                case decode.run(row, stats_decoder()) {
                  Ok(stats) -> Ok(stats)
                  Error(_) -> Error(db.QueryError("Failed to decode stats"))
                }
              }
              _ -> Error(db.QueryError("No stats returned"))
            }
          }
          Error(e) -> Error(e)
        }
      })
    },
    fn(e: DbError) { e }
  )
}

// Simple decoder - just decode string then parse (like PostgreSQL bigint)
fn decode_bigint() -> decode.Decoder(Int) {
  decode.string
    |> decode.map(fn(s) {
      case int.parse(s) {
        Ok(n) -> n
        Error(_) -> 0
      }
    })
}

fn stats_decoder() -> decode.Decoder(Stats) {
  use tasks <- decode.field("tasks", decode_bigint())
  use issues <- decode.field("issues", decode_bigint())
  use skills <- decode.field("skills", decode_bigint())
  use meetings <- decode.field("meetings", decode_bigint())

  decode.success(Stats(tasks, issues, skills, meetings))
}

// -------------------------------------------------------------------
// Pi Tool Call definition
// -------------------------------------------------------------------

/// Pi tool: psypi-stats — show project statistics
pub fn stats_show_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-stats-show",
    description: "Show project statistics (tasks, issues, skills, meetings)",
    params: [],
    module: "stats",
    fn_name: "stats",
    args: [],
    result_format: custom_js("`Tasks:${r.value.tasks} Issues:${r.value.issues} Skills:${r.value.skills} Meetings:${r.value.meetings}`"),
  )
}
