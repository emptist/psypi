// task.gleam - Task management (~50 lines)
// Small + Pure = Resilience!




pub type TaskError {
  DatabaseError(String)
  NotFound(String)
  InvalidInput(String)
}

pub fn add_task(title: String, description: String, priority: Int) -> Result(String, TaskError) {
  // TODO: Call PostgreSQL via FFI
  Ok("Task created: " <> title)
}

pub fn list_tasks(status: String) -> Result(String, TaskError) {
  // TODO: Query tasks from DB
  Ok("Tasks listed")
}

pub fn complete_task(task_id: String) -> Result(String, TaskError) {
  // TODO: Update task status
  Ok("Task completed: " <> task_id)
}
