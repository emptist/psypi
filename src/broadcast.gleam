import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, from_param, template}
import project.{project_url}

pub type BroadcastPriority {
  Low
  Normal
  High
  Critical
}

pub type BroadcastStatus {
  Pending
  Sent
  Failed
  Cancelled
}

pub type Broadcast {
  Broadcast(
    id: String,
    agent_id: String,
    message: String,
    priority: BroadcastPriority,
    status: BroadcastStatus,
    created_at: String,
    sent_at: Option(String),
  )
}

pub type BroadcastError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

pub fn priority_to_string(p: BroadcastPriority) -> String {
  case p {
    Low -> "low"
    Normal -> "normal"
    High -> "high"
    Critical -> "critical"
  }
}

pub fn string_to_priority(s: String) -> Result(BroadcastPriority, String) {
  case s {
    "critical" -> Ok(Critical)
    "high" -> Ok(High)
    "normal" -> Ok(Normal)
    "low" -> Ok(Low)
    _ -> Error("Unknown priority: " <> s)
  }
}

fn string_to_status(s: String) -> Result(BroadcastStatus, String) {
  case s {
    "sent" -> Ok(Sent)
    "failed" -> Ok(Failed)
    "cancelled" -> Ok(Cancelled)
    "pending" -> Ok(Pending)
    _ -> Error("Unknown broadcast status: " <> s)
  }
}

fn broadcast_row_decoder() -> decode.Decoder(#(String, String, String, String, String, String, Option(String))) {
  use id <- decode.field("id", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use message <- decode.field("message", decode.string)
  use priority_str <- decode.field("priority", decode.string)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use sent_at <- decode.field("sent_at", decode.optional(decode.string))
  decode.success(#(id, agent_id, message, priority_str, status_str, created_at, sent_at))
}

fn broadcast_decoder() -> decode.Decoder(Broadcast) {
  broadcast_row_decoder()
  |> decode.then(fn(row) {
    let #(id, agent_id, message, priority_str, status_str, created_at, sent_at) = row
    case string_to_priority(priority_str) {
      Error(_) -> decode.failure(Broadcast(id: id, agent_id: agent_id, message: message, priority: Low, status: Pending, created_at: created_at, sent_at: sent_at), "Unknown priority: " <> priority_str)
      Ok(priority) -> {
        case string_to_status(status_str) {
          Error(_) -> decode.failure(Broadcast(id: id, agent_id: agent_id, message: message, priority: priority, status: Pending, created_at: created_at, sent_at: sent_at), "Unknown status: " <> status_str)
          Ok(status) -> decode.success(Broadcast(
            id: id,
            agent_id: agent_id,
            message: message,
            priority: priority,
            status: status,
            created_at: created_at,
            sent_at: sent_at,
          ))
        }
      }
    }
  })
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn stats_decoder() -> decode.Decoder(#(Int, Int, Int)) {
  use total <- decode.field("total", decode.int)
  use sent_count <- decode.field("sent_count", decode.int)
  use high_priority_count <- decode.field("high_priority_count", decode.int)
  decode.success(#(total, sent_count, high_priority_count))
}

fn db_error_to_broadcast_error(e: db.DbError) -> BroadcastError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn send(
  agent_id: String,
  message: String,
  priority_str: String,
) -> promise.Promise(Result(String, BroadcastError)) {
  let project_url = project_url()
  case string_to_priority(priority_str) {
    Error(e) -> promise.resolve(Error(DecodeError(e)))
    Ok(priority) -> {
      db.with_connection(fn(conn) {
        let sql = "
          INSERT INTO project_communications
          (project_url, from_ai, message_type, content, priority, metadata)
          VALUES ($1, $2, 'broadcast', $3, $4, $5)
          RETURNING id
        "
        let params = [
          dynamic.string(project_url),
          dynamic.string(agent_id),
          dynamic.string(message),
          dynamic.string(priority_to_string(priority)),
          dynamic.string("{\"sent_at\": \"now\"}"),
        ]

        promise.map(db.query(conn, sql, params), fn(query_result) {
          case query_result {
            Error(e) -> Error(db_error_to_broadcast_error(e))
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
      }, db_error_to_broadcast_error)
    }
  }
}

fn decode_rows(
  rows: List(Dynamic),
  decoder: decode.Decoder(a),
) -> Result(List(a), BroadcastError) {
  case rows {
    [] -> Ok([])
    [row, ..rest] -> {
      case decode.run(row, decoder) {
        Error(_) -> Error(DecodeError("Failed to decode row"))
        Ok(value) -> {
          case decode_rows(rest, decoder) {
            Error(e) -> Error(e)
            Ok(rest_values) -> Ok([value, ..rest_values])
          }
        }
      }
    }
  }
}

pub fn list(
  agent_id: Option(String),
  limit: Int,
) -> promise.Promise(Result(List(Broadcast), BroadcastError)) {
  db.with_connection(fn(conn) {
    let sql = case agent_id {
      Some(_) -> "
        SELECT id, from_ai as agent_id, content as message, priority,
               'sent' as status, created_at::text, read_at::text as sent_at
        FROM project_communications
        WHERE from_ai = $1 AND message_type = 'broadcast'
        ORDER BY created_at DESC
        LIMIT $2
      "
      None -> "
        SELECT id, from_ai as agent_id, content as message, priority,
               'sent' as status, created_at::text, read_at::text as sent_at
        FROM project_communications
        WHERE message_type = 'broadcast'
        ORDER BY created_at DESC
        LIMIT $1
      "
    }

    let params = case agent_id {
      Some(id) -> [dynamic.string(id), dynamic.int(limit)]
      None -> [dynamic.int(limit)]
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_broadcast_error(e))
        Ok(result) -> decode_rows(result.rows, broadcast_decoder())
      }
    })
  }, db_error_to_broadcast_error)
}

pub fn get_recent(
  agent_id: String,
  count: Int,
) -> promise.Promise(Result(List(Broadcast), BroadcastError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, from_ai as agent_id, content as message, priority,
             'sent' as status, created_at::text, read_at::text as sent_at
      FROM project_communications
      WHERE from_ai = $1 AND message_type = 'broadcast'
      ORDER BY created_at DESC
      LIMIT $2
    "
    let params = [dynamic.string(agent_id), dynamic.int(count)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_broadcast_error(e))
        Ok(result) -> decode_rows(result.rows, broadcast_decoder())
      }
    })
  }, db_error_to_broadcast_error)
}

pub fn stats(
  agent_id: String,
) -> promise.Promise(Result(#(Int, Int, Int), BroadcastError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT
        COUNT(*)::int as total,
        COUNT(*)::int as sent_count,
        COUNT(*) FILTER (WHERE priority IN ('high', 'critical'))::int as high_priority_count
      FROM project_communications
      WHERE from_ai = $1 AND message_type = 'broadcast'
    "
    let params = [dynamic.string(agent_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_broadcast_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, stats_decoder()) {
                Ok(stats) -> Ok(stats)
                Error(_) -> Error(DecodeError("Failed to decode stats"))
              }
            }
            _ -> Error(NotFound("No stats returned"))
          }
        }
      }
    })
  }, db_error_to_broadcast_error)
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-broadcast-send — send a broadcast message
pub fn broadcast_send_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-broadcast-send",
    description: "Send a broadcast message",
    params: [string_param("message"), string_param("priority")],
    module: "broadcast",
    fn_name: "send",
    args: [
      from_param("'psypi'"),
      from_param("params.message || \"\""),
      from_param("params.priority || 'normal'"),
    ],
    result_format: template("Broadcast sent: ${r.value}"),
  )
}

/// Pi tool: psypi-broadcasts — list broadcasts
pub fn broadcast_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-broadcasts",
    description: "List broadcast messages",
    params: [string_param("limit")],
    module: "broadcast",
    fn_name: "list",
    args: [
      from_param("null"),
      from_param("parseInt(params.limit || '10')"),
    ],
    result_format: template("Broadcasts: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}
