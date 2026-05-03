import gleam/dynamic
import gleam/javascript/promise
import gleam/list
import gleam/string
import psypi_cli/db

pub type ReflectionError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

pub type ReflectionResult {
  ReflectionResult(
    learnings: Int,
    issues: Int,
    tasks: Int,
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
) -> Result(#(List(String), List(String), List(String)), String) {
  let learnings = parse_marker(text, "[LEARN]")
  let issues = parse_marker(text, "[ISSUE]")
  let tasks = parse_marker(text, "[TASK]")
  Ok(#(learnings, issues, tasks))
}

pub fn areflect(
  text: String,
  agent_id: String,
) -> promise.Promise(Result(ReflectionResult, ReflectionError)) {
  let #(learnings, issues, tasks) = case parse(text) {
    Ok(result) -> result
    Error(_) -> #([], [], [])
  }

  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        promise.await(save_learnings(conn, learnings, agent_id), fn(_) {
          promise.await(save_issues(conn, issues, agent_id), fn(_) {
            promise.await(save_tasks(conn, tasks, agent_id), fn(_) {
              let _ = db.disconnect(conn)
              promise.resolve(Ok(ReflectionResult(
                learnings: list.length(learnings),
                issues: list.length(issues),
                tasks: list.length(tasks),
              )))
            })
          })
        })
      }
    }
  })
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

  promise.await(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(_) -> Error(QueryError("Query failed"))
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
  let sql = "
    INSERT INTO issues (title, description, severity, created_by)
    VALUES ($1, $2, 'medium', $3)
  "
  let title = case string.split(content, "\n") {
    [first, ..] -> string.slice(first, 0, 200)
    _ -> string.slice(content, 0, 200)
  }
  let params = [dynamic.string(title), dynamic.string(content), dynamic.string(agent_id)]

  promise.await(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(_) -> Error(QueryError("Query failed"))
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
  let sql = "
    INSERT INTO tasks (title, description, priority, created_by)
    VALUES ($1, $2, 5, $3)
  "
  let title = case string.split(content, "\n") {
    [first, ..] -> string.slice(first, 0, 200)
    _ -> string.slice(content, 0, 200)
  }
  let params = [dynamic.string(title), dynamic.string(content), dynamic.string(agent_id)]

  promise.await(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(_) -> Error(QueryError("Query failed"))
      Ok(_) -> Ok(Nil)
    }
  })
}
