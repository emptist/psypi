import db
import pi_tool_call.{ type PiToolCall, PiToolCall, raw_json, template, lit, from_param, string_param, opt_string_param, int_param }
import project as proj

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
    description: String,
    priority: Int,
    created_by: String,
    project_id: String,
    created_at: String,
    updated_at: String,
  )
}

pub type TaskError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
}

fn db_error_to_task_error(e: db.DbError) -> TaskError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn proj_error_to_task_error(e: proj.ProjectError) -> TaskError {
  case e {
    proj.ConnectionError(msg) -> ConnectionError(msg)
    proj.QueryError(msg) -> QueryError(msg)
    proj.NotFound(msg) -> QueryError("Project not found: " <> msg)
  }
}

fn id_decoder() -> decode.Decoder(String) {
  decode.field("id", decode.string)
}

pub fn task_type_decoder() -> decode.Decoder(Task) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use priority <- decode.field("priority", decode.int)
  use created_by <- decode.field("created_by", decode.string)
  use project_id <- decode.field("project_id", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(Task(
    id: id,
    title: title,
    description: description,
    priority: priority,
    created_by: created_by,
    project_id: project_id,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

pub fn add(
  title: String,
  description: String,
  priority: Int,
  created_by: String,
  cwd: String,
) -> promise.Promise(Result(String, TaskError)) {
  promise.await(proj.resolve_or_create(cwd), fn(project_result) {
    case project_result {
      Ok(project_id) ->
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
              Ok(result) ->
                case result.rows {
                  [row, ..] ->
                    case decode.run(row, id_decoder()) {
                      Ok(id) -> Ok(id)
                      Error(_) -> Error(DecodeError("Failed to decode id"))
                    }
                  _ -> Error(NotFound("No id returned"))
                }
            }
          })
        })
      Error(e) -> Error(proj_error_to_task_error(e))
    }
  })
}

pub fn task_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-task-add",
    description: "Add a new task",
    params: [string_param("title"), opt_string_param("description"), int_param("priority"), opt_string_param("created_by")],
    module: "task",
    fn_name: "add",
    args: [
      from_param("params.title || ''"),
      from_param("params.description || ''"),
      from_param("(params.priority || 5)"),
      from_param("'psypi'"),
      lit("ctx.cwd || ''"),
    ],
    result_format: template("Added task `${id}`"),
  )
}