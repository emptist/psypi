import db
import db_utils
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import pi_tool_call.{type PiToolCall, PiToolCall, template}

pub type Agent {
  Agent(
    id: String,
    agent_type: String,
    created_at: String,
  )
}

pub type AgentError {
  ConnectionError(String)
  QueryError(String)
}

fn db_error_to_agent_error(e: db.DbError) -> AgentError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn agent_decoder() -> decode.Decoder(Agent) {
  use id <- decode.field("id", decode.string)
  use agent_type <- decode.field("agent_type", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Agent(id:, agent_type:, created_at:))
}

/// List agents from database
pub fn list() -> promise.Promise(Result(List(Agent), AgentError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, agent_type, created_at::text 
      FROM agent_identities 
      ORDER BY created_at DESC 
      LIMIT 50
    "
    let params: List(dynamic.Dynamic) = []

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_agent_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, agent_decoder()) })
          case db_utils.decode_all_results(decoded) {
            Error(_) -> Error(QueryError("Failed to decode agent row"))
            Ok(agents) -> Ok(agents)
          }
        }
      }
    })
  }, db_error_to_agent_error)
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-agents — list all agents
pub fn agents_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-agents",
    description: "List all registered agents",
    params: [],
    module: "agents",
    fn_name: "list",
    args: [],
    result_format: template("Agents: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}
