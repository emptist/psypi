import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi_cli/db

pub type TaskStatus {
  Pending
  Running
  Completed
  Failed
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
  )
}

pub type TaskError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn string_to_status(s: String) -> TaskStatus {
  case s {
    "RUNNING" -> Running
    "COMPLETED" -> Completed
    "FAILED" -> Failed
    _ -> Pending
  }
}

fn task_decoder() -> decode.Decoder(Task) {
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

  decode.success(Task(
    id: id,
    title: title,
    description: description,
    status: string_to_status(status_str),
    priority: priority,
    result: result,
    error: error,
    retry_count: retry_count,
    created_at: created_at,
    updated_at: updated_at,
    completed_at: completed_at,
    created_by: created_by,
  ))
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn db_error_to_task_error(e: db.DbError) -> TaskError {
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
) -> promise.Promise(Result(String, TaskError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO tasks (title, description, priority, created_by)
      VALUES ($1, $2, $3, $4)
      RETURNING id
    "
    let params = [
      dynamic.string(title),
      dynamic.string(description),
      dynamic.int(priority),
      dynamic.string(created_by),
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
) -> promise.Promise(Result(List(Task), TaskError)) {
  db.with_connection(fn(conn) {
    let sql = case status {
      Some(_) -> "
        SELECT id, title, description, status, priority, result, error, retry_count,
               created_at::text, updated_at::text, completed_at::text, created_by
        FROM tasks
        WHERE status = $1
        ORDER BY priority DESC, created_at ASC
        LIMIT 100
      "
      None -> "
        SELECT id, title, description, status, priority, result, error, retry_count,
               created_at::text, updated_at::text, completed_at::text, created_by
        FROM tasks
        ORDER BY priority DESC, created_at ASC
        LIMIT 100
      "
    }

    let params = case status {
      Some(s) -> [dynamic.string(s)]
      None -> []
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_task_error(e))
        Ok(result) -> {
          let tasks = result.rows
            |> list.map(fn(row) { decode.run(row, task_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(tasks)
        }
      }
    })
  }, db_error_to_task_error)
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
             created_at::text, updated_at::text, completed_at::text, created_by
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
