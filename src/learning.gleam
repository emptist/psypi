import gleam/dynamic
import gleam/javascript/promise
import gleam/list
import gleam/string
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, from_param, template}

pub type LearningError {
  ConnectionError(String)
  QueryError(String)
}

fn db_error_to_learning_error(e: db.DbError) -> LearningError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn tags_to_array_literal(tags: String) -> String {
  let trimmed = string.trim(tags)
  case trimmed {
    "" -> "{}"
    _ ->
      trimmed
      |> string.split(",")
      |> list.map(fn(t) { string.trim(t) })
      |> string.join(",")
      |> fn(s) { "{" <> s <> "}" }
  }
}

fn save_learning(
  conn: db.Connection,
  content: String,
  tags: String,
  importance: Int,
  agent_id: String,
) -> promise.Promise(Result(Nil, LearningError)) {
  let sql = "
    INSERT INTO memory (content, tags, source, importance, agent_id)
    VALUES ($1, $2, 'learn', $3, $4)
  "
  let params = [
    dynamic.string(content),
    dynamic.string(tags_to_array_literal(tags)),
    dynamic.int(importance),
    dynamic.string(agent_id),
  ]

  promise.map(db.query(conn, sql, params), fn(query_result) {
    case query_result {
      Error(e) -> Error(db_error_to_learning_error(e))
      Ok(_) -> Ok(Nil)
    }
  })
}

pub fn save(
  content: String,
  tags: String,
  importance: Int,
  agent_id: String,
) -> promise.Promise(Result(Nil, LearningError)) {
  db.with_connection(fn(conn) {
    save_learning(conn, content, tags, importance, agent_id)
  }, db_error_to_learning_error)
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-learn-save — save a learning
pub fn learn_save_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-learn-save",
    description: "Save a learning to memory",
    params: [string_param("content"), string_param("tags"), string_param("importance")],
    module: "learning",
    fn_name: "save",
    args: [
      from_param("params.content || \"\""),
      from_param("params.tags || \"\""),
      from_param("parseInt(params.importance || '5')"),
      from_param("'psypi'"),
    ],
    result_format: template("Learning saved"),
  )
}
