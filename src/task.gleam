import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db
import pi_tool_call.{type PiToolCall, PiToolCall, raw_json, template, lit, from_param, string_param, opt_string_param}

pub type TaskStatus {
  Pending
  Running
  Completed
  Failed
  FakeComplete
}

pub type Task {
  Task(
    id: String,
    title: String,
    description: Option(String),
    status: TaskStatus,
    priority: Int,
    result: Option(String),
    error: Option(String),
    retry_count: Int,
    created_at: String,
    updated_at: String,
    completed_at: Option(String),
    created_by: String,
    source: Option(String),
    project_id: Option(String),
  )
}

pub type TaskError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

pub fn string_to_status(s: String) -> Result(TaskStatus, String) {
  case s {
    "pending" | "PENDING" -> Ok(Pending)
    "running" | "RUNNING" -> Ok(Running)
    "completed" | "COMPLETED" -> Ok(Completed)
    "failed" | "FAILED" -> Ok(Failed)
    "fake_complete" | "FAKE_COMPLETE" -> Ok(FakeComplete)
    _ -> Error("Unknown task status: " <> s)
  }
}

pub fn task_decoder() -> decode.Decoder(Task) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use priority <- decode.field("priority", decode.int)
  use result <- decode.field("result", decode.optional(decode.string))
  use error <- decode.field("error", decode.optional(decode.string))
  use retry_count <- decode.field("retry_count", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use completed_at <- decode.field("completed_at", decode.optional(decode.string))
  use created_by <- decode.field("created_by", decode.string)
  use source <- decode.field("source", decode.optional(decode.string))
  use project_id <- decode.field("project_id", decode.optional(decode.string))

  case string_to_status(status_str) {
    Error(_) -> decode.failure(Task(id: id, title: title, description: description, status: Pending, priority: priority, result: result, error: error, retry_count: retry_count, created_at: created_at, updated_at: updated_at, completed_at: completed_at, created_by: created_by, source: source, project_id: project_id), "Unknown task status: " <> status_str)
    Ok(status) -> decode.success(Task(
      id: id,
      title: title,
      description: description,
      status: status,
      priority: priority,
      result: result,
      error: error,
      retry_count: retry_count,
      created_at: created_at,
      updated_at: updated_at,
      completed_at: completed_at,
      created_by: created_by,
      source: source,
      project_id: project_id,
    ))
  }
}

fn decode_all_results(results: List(Result(a, b))) -> Result(List(a), b) {
  case results {
    [] -> Ok([])
    [Ok(v), ..rest] -> {
      case decode_all_results(rest) {
        Error(e) -> Error(e)
        Ok(vs) -> Ok([v, ..vs])
      }
    }
    [Error(e), .._] -> Error(e)
  }
}

pub fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

pub fn db_error_to_task_error(e: db.DbError) -> TaskError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn add(
  title: String,
  description: String,
  priority: Int,
  created_by: String,
  project_id: String,
) -> promise.Promise(Result(String, TaskError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO tasks (title, description, priority, created_by, project_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
    "
    let params = [
      dynamic.string(title),
      dynamic.string(description),
      dynamic.int(priority),
      dynamic.string(created_by),
      dynamic.string(project_id),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_task_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("No id returned"))
          }
        }
      }
    })
  }, db_error_to_task_error)
}

pub fn list(
  status: Option(String),
  project_id: Option(String),
) -> promise.Promise(Result(List(Task), TaskError)) {
  db.with_connection(fn(conn) {
    let #(sql, params) = sql_with_filters(status, project_id)

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_task_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, task_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode task row"))
            Ok(tasks) -> Ok(tasks)
          }
        }
      }
    })
  }, db_error_to_task_error)
}

fn sql_with_filters(
  status: Option(String),
  project_id: Option(String),
) -> #(String, List(dynamic.Dynamic)) {
  let base_sql = "
    SELECT id, title, description, status, priority, result, error, retry_count,
           created_at::text, updated_at::text, completed_at::text, created_by, source,
           project_id::text
    FROM tasks
  "
  let order_limit = " ORDER BY priority DESC, created_at ASC LIMIT 100 "

  case status, project_id {
    Some(s), Some(p) ->
      #(base_sql <> " WHERE status = $1 AND project_id = $2 " <> order_limit,
        [dynamic.string(s), dynamic.string(p)])
    Some(s), None ->
      #(base_sql <> " WHERE status = $1 " <> order_limit,
        [dynamic.string(s)])
    None, Some(p) ->
      #(base_sql <> " WHERE project_id = $1 " <> order_limit,
        [dynamic.string(p)])
    None, None ->
      #(base_sql <> order_limit, [])
  }
}

pub fn complete(
  task_id: String,
) -> promise.Promise(Result(String, TaskError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE tasks
      SET status = 'COMPLETED', completed_at = NOW()
      WHERE id = $1
      RETURNING id
    "
    let params = [dynamic.string(task_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_task_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("Task not found"))
          }
        }
      }
    })
  }, db_error_to_task_error)
}

pub fn get(
  task_id: String,
) -> promise.Promise(Result(Task, TaskError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, title, description, status, priority, result, error, retry_count,
             created_at::text, updated_at::text, completed_at::text, created_by, source
      FROM tasks
      WHERE id = $1
    "
    let params = [dynamic.string(task_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_task_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, task_decoder()) {
                Ok(task) -> Ok(task)
                Error(_) -> Error(DecodeError("Failed to decode task"))
              }
            }
            _ -> Error(NotFound("Task not found"))
          }
        }
      }
    })
  }, db_error_to_task_error)
}

// -------------------------------------------------------------------
// Pi Tool Call definitions
// -------------------------------------------------------------------

/// Pi tool: psypi-task-add — add a new task
pub fn task_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-task-add",
    description: "Add a new task. project_id optional (defaults to default project).",
    params: [string_param("title"), opt_string_param("project_id")],
    module: "task",
    fn_name: "add",
    args: [
      from_param("params.title || \"\""),
      lit("\"\""),
      lit("5"),
      lit("\"cli\""),
      from_param("params?.project_id || '0d324e68-b399-4b85-bd8a-6b1ef7b46168'"),
    ],
    result_format: template("Task: ${r.value}"),
  )
}

/// Pi tool: psypi-tasks — list tasks
pub fn task_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-tasks",
    description: "List tasks, optionally filtered by status and project_id",
    params: [
      opt_string_param("status"),
      opt_string_param("project_id"),
    ],
    module: "task",
    fn_name: "list",
    args: [
      from_param("params?.status || null"),
      from_param("params?.project_id || null"),
    ],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-task-complete — mark a task as completed
pub fn task_complete_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-task-complete",
    description: "Mark a task as completed",
    params: [string_param("task_id")],
    module: "task",
    fn_name: "complete",
    args: [
      from_param("params.task_id || \"\""),
    ],
    result_format: template("Task completed: ${r.value}"),
  )
}
