import gleam/javascript/promise
import gleam/json
import psypi/db
import psypi/agent_identity_types.{type AgentIdentity, type IdentityError, ConnectionError, QueryError, agent_id}
import psypi/agent_identity_db.{insert_identity, fetch_identity_by_id}
import psypi/agent_identity_logic.{generate_semantic_id}
import psypi/activity_log
import psypi/pi_tool_call.{type PiToolCall, PiToolCall, raw_json, lit}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Get or create the resolved agent identity.
/// This is the SINGLE SOURCE OF truth for agent identity.
/// Session_id is passed in ONCE from JS (fromPi ctx), then封装进 AgentIdentity.
pub fn get_resolved_identity(
  permanent: Bool,
  session_id: String,
  project: String,
  git_hash: String,
  machine_fingerprint: String,
  source: String,
  model: String,
) -> promise.Promise(Result(AgentIdentity, IdentityError)) {
  db.with_connection(fn(conn) {
    let id = generate_semantic_id(permanent, source, project, session_id, model)

    promise.await(insert_identity(conn, id, project, git_hash, machine_fingerprint, source, session_id), fn(insert_result) {
      case insert_result {
        Ok(_) -> {
          promise.await(fetch_identity_by_id(conn, id), fn(fetch_result) {
            case fetch_result {
              Ok(identity) -> {
                // ID Trigger: log that identity was resolved
                // Fire-and-forget: don't block the identity return
                let context = json.to_string(json.object([
                  #("permanent", json.bool(permanent)),
                  #("session_id", json.string(session_id)),
                  #("project", json.string(project)),
                  #("source", json.string(source)),
                  #("model", json.string(model)),
                ]))
                promise.map(activity_log.log_activity(agent_id(identity.id), "get_resolved_identity", context), fn(_) {
                  Ok(identity)
                })
              }
              Error(e) -> promise.resolve(Error(e))
            }
          })
        }
        Error(e) -> promise.resolve(Error(e))
      }
    })
  }, db_error_to_identity_error)
}

// -------------------------------------------------------------------
// Pi Tool Call definitions
// Each module that wants to expose a Pi tool defines a PiToolCall value.
// The generator collects these and composes them into extension.js.
// -------------------------------------------------------------------

/// Pi tool: psypi-my-id — get current agent ID (permanent=false)
/// session_id is obtained from Pi ctx's session_start hook
pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get current agent ID",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("false"),
      lit("_sessionId"),
      lit("\"psypi\""),
      lit("\"\""),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
    ],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-monitor-id — get monitor/partner ID (permanent=true)
pub fn monitor_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-monitor-id",
    description: "Get monitor/partner ID (permanent identity)",
    params: [],
    module: "agent_identity",
    fn_name: "get_resolved_identity",
    args: [
      lit("true"),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
      lit("\"\""),
      lit("\"psypi\""),
      lit("\"\""),
    ],
    result_format: raw_json(),
  )
}
