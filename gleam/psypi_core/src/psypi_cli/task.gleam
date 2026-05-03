import gleam/option.{type Option, None, Some}

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
  DatabaseError(String)
  NotFound(String)
  InvalidInput(String)
}

@external(javascript, "./task_ffi.mjs", "add_task")
fn add_task_ffi(
  title: String,
  description: String,
  priority: Int,
  created_by: String,
) -> Result(String, String)

@external(javascript, "./task_ffi.mjs", "list_tasks")
fn list_tasks_ffi(status: Option(String)) -> Result(List(Task), String)

@external(javascript, "./task_ffi.mjs", "complete_task")
fn complete_task_ffi(task_id: String) -> Result(String, String)

@external(javascript, "./task_ffi.mjs", "get_task")
fn get_task_ffi(task_id: String) -> Result(Task, String)

pub fn add(title: String, description: String, priority: Int, created_by: String) -> Result(String, TaskError) {
  case add_task_ffi(title, description, priority, created_by) {
    Ok(id) -> Ok(id)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn list(status: Option(String)) -> Result(List(Task), TaskError) {
  case list_tasks_ffi(status) {
    Ok(tasks) -> Ok(tasks)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn complete(task_id: String) -> Result(String, TaskError) {
  case complete_task_ffi(task_id) {
    Ok(id) -> Ok(id)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn get(task_id: String) -> Result(Task, TaskError) {
  case get_task_ffi(task_id) {
    Ok(task) -> Ok(task)
    Error(e) -> Error(DatabaseError(e))
  }
}

pub fn status_to_string(status: TaskStatus) -> String {
  case status {
    Pending -> "PENDING"
    Running -> "RUNNING"
    Completed -> "COMPLETED"
    Failed -> "FAILED"
  }
}

pub fn string_to_status(s: String) -> TaskStatus {
  case s {
    "RUNNING" -> Running
    "COMPLETED" -> Completed
    "FAILED" -> Failed
    _ -> Pending
  }
}
