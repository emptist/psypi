import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/result
import gleam/string
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, from_param, template}
import project.{project_url}

pub type ReflectionError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

pub type IssueSummary {
  IssueSummary(id: String, title: String, status: String, severity: String)
}

pub type ReflectionResult {
  ReflectionResult(
    learnings: Int,
    issues: Int,
    tasks: Int,
    issue_list: List(IssueSummary),
  )
}

fn parse_marker(text: String, marker: String) -> List(String) {
  text
    |> string.split("\n")
    |> list.filter(fn(line) { string.contains(line, marker) })
    |> list.map(fn(line) {
      line
        |> string.replace(marker, "")
        |> string.trim
    })
    |> list.filter(fn(s) { string.length(s) > 0 })
}

pub fn parse(
  text: String,
) -> Result(#(List(String), List(String), List(String), Int), String) {
  let learnings = parse_marker(text, "[LEARN]")
  let issues = parse_marker(text, "[ISSUE]")
  let tasks = parse_marker(text, "[TASK]")
  case parse_issue_list_marker(text) {
    Error(e) -> Error(e)
    Ok(issue_list_count) -> Ok(#(learnings, issues, tasks, issue_list_count))
  }
}

fn parse_issue_list_marker(text: String) -> Result(Int, String) {
  text
  |> string.split("\n")
  |> list.filter(fn(line) { string.contains(line, "[ISSUELIST]") })
  |> list.first
  |> result.map(fn(line) {
    line
    |> string.replace("[ISSUELIST]", "")
    |> string.trim
    |> parse_count_from_issue_list
  })
  |> result.unwrap(Error("No [ISSUELIST] marker found"))
}

fn parse_count_from_issue_list(s: String) -> Result(Int, String) {
  let parts = string.split(s, " ")
  let count_str = case list.drop(parts, 1) {
    [first, ..] -> first
    _ -> s
  }
  case int.parse(count_str) {
    Ok(n) -> Ok(n)
    Error(_) -> Error("Invalid ISSUELIST count: " <> count_str)
  }
}

fn db_error_to_reflection_error(e: db.DbError) -> ReflectionError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn areflect(
  text: String,
  agent_id: String,
) -> promise.Promise(Result(ReflectionResult, ReflectionError)) {
  case parse(text) {
    Error(e) -> promise.resolve(Error(DecodeError(e)))
    Ok(#(learnings, issues, tasks, issue_list_count)) -> {
      db.with_connection(fn(conn) {
        promise.await(save_learnings(conn, learnings, agent_id), fn(_) {
          promise.await(save_issues(conn, issues, agent_id), fn(_) {
            promise.await(save_tasks(conn, tasks, agent_id), fn(_) {
              promise.map(fetch_recent_issues(conn, issue_list_count), fn(issue_list) {
                case issue_list {
                  Ok(issues) -> Ok(ReflectionResult(
                    learnings: list.length(learnings),
                    issues: list.length(issues),
                    tasks: list.length(tasks),
                    issue_list: issues,
                  ))
                  Error(e) -> Error(e)
                }
              })
            })
          })
        })
      }, db_error_to_reflection_error)
    }
  }
}

fn issue_summary_decoder() -> decode.Decoder(IssueSummary) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use status <- decode.field("status", decode.string)
  use severity <- decode.field("severity", decode.string)
  decode.success(IssueSummary(id: id, title: title, status: status, severity: severity))
}

fn fetch_recent_issues(
  conn: db.Connection,
  count: Int,
) -> promise.Promise(Result(List(IssueSummary), ReflectionError)) {
  case count {
    0 -> promise.resolve(Ok([]))
    _ -> {
      let sql = "
        SELECT id, title, status, severity
        FROM issues
        ORDER BY 
          CASE severity 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'medium' THEN 3 
            WHEN 'low' THEN 4 
            ELSE 5 
          END,
          created_at DESC
        LIMIT $1
      "
      let params = [dynamic.int(count)]
      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Ok(result) -> {
            let decoded = result.rows
              |> list.map(fn(row) { decode.run(row, issue_summary_decoder()) })
              |> list.try_map(fn(r) { r })
            case decoded {
              Error(_) -> Error(DecodeError("Failed to decode issue row"))
              Ok(issues) -> Ok(issues)
            }
          }
          Error(_) -> Error(QueryError("Failed to fetch issues"))
        }
      })
    }
  }
}

fn save_learnings(
  conn: db.Connection,
  learnings: List(String),
  agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  case learnings {
    [] -> promise.resolve(Ok(Nil))
    [first, ..rest] -> {
      promise.await(save_learning(conn, first, agent_id), fn(_) {
        save_learnings(conn, rest, agent_id)
      })
    }
  }
}

fn save_learning(
  conn: db.Connection,
  content: String,
  _agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  let sql = "
    INSERT INTO learning_insights (insight_type, title, content, confidence)
    VALUES ('pattern', $1, $2, 0.8)
  "
  let title = case string.split(content, "\n") {
    [first, ..] -> string.slice(first, 0, 100)
    _ -> string.slice(content, 0, 100)
  }
  let params = [dynamic.string(title), dynamic.string(content)]

  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(e) -> Error(db_error_to_reflection_error(e))
      Ok(_) -> Ok(Nil)
    }
  })
}

fn save_issues(
  conn: db.Connection,
  issues: List(String),
  agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  case issues {
    [] -> promise.resolve(Ok(Nil))
    [first, ..rest] -> {
      promise.await(save_issue(conn, first, agent_id), fn(_) {
        save_issues(conn, rest, agent_id)
      })
    }
  }
}

fn save_issue(
  conn: db.Connection,
  content: String,
  agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  let project_url = project_url()
  let sql = "
    INSERT INTO issues (title, description, severity, created_by, project_url)
    VALUES ($1, $2, 'medium', $3, $4)
  "
  let title = case string.split(content, "\n") {
    [first, ..] -> string.slice(first, 0, 200)
    _ -> string.slice(content, 0, 200)
  }
  let params = [dynamic.string(title), dynamic.string(content), dynamic.string(agent_id), dynamic.string(project_url)]

  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(e) -> Error(db_error_to_reflection_error(e))
      Ok(_) -> Ok(Nil)
    }
  })
}

fn save_tasks(
  conn: db.Connection,
  tasks: List(String),
  agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  case tasks {
    [] -> promise.resolve(Ok(Nil))
    [first, ..rest] -> {
      promise.await(save_task(conn, first, agent_id), fn(_) {
        save_tasks(conn, rest, agent_id)
      })
    }
  }
}

fn save_task(
  conn: db.Connection,
  content: String,
  agent_id: String,
) -> promise.Promise(Result(Nil, ReflectionError)) {
  let project_url = project_url()
  let sql = "
    INSERT INTO tasks (title, description, priority, created_by, project_url)
    VALUES ($1, $2, 5, $3, $4)
  "
  let title = case string.split(content, "\n") {
    [first, ..] -> string.slice(first, 0, 200)
    _ -> string.slice(content, 0, 200)
  }
  let params = [dynamic.string(title), dynamic.string(content), dynamic.string(agent_id), dynamic.string(project_url)]

  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(e) -> Error(db_error_to_reflection_error(e))
      Ok(_) -> Ok(Nil)
    }
  })
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-areflect — extract learnings, issues, and tasks from text
pub fn areflect_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-areflect",
    description: "Extract [LEARN], [ISSUE], [TASK], [ISSUELIST] markers from text and save to database",
    params: [string_param("text")],
    module: "areflect",
    fn_name: "areflect",
    args: [
      from_param("params.text || \"\""),
      from_param("'psypi'"),
    ],
    result_format: template("Reflection: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}
