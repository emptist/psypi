import gleam/javascript/promise
import psypi_cli/db.{type DbError, type Connection, with_connection}
import gleam/dynamic/decode

pub type Stats {
  Stats(
    tasks: Int,
    issues: Int,
    skills: Int,
    meetings: Int,
  )
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
    fn(e: DbError) { e } // 直接返回错误，不是 Error(e)
  )
}

fn stats_decoder() -> decode.Decoder(Stats) {
  use tasks <- decode.field("tasks", decode.int)
  use issues <- decode.field("issues", decode.int)
  use skills <- decode.field("skills", decode.int)
  use meetings <- decode.field("meetings", decode.int)
  
  decode.success(Stats(tasks, issues, skills, meetings))
}
