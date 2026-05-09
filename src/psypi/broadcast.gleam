import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi/db

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

pub fn string_to_priority(s: String) -> BroadcastPriority {
  case s {
    "critical" -> Critical
    "high" -> High
    "normal" -> Normal
    _ -> Low
  }
}

fn string_to_status(s: String) -> BroadcastStatus {
  case s {
    "sent" -> Sent
    "failed" -> Failed
    "cancelled" -> Cancelled
    _ -> Pending
  }
}

fn broadcast_decoder() -> decode.Decoder(Broadcast) {
  use id <- decode.field("id", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use message <- decode.field("message", decode.string)
  use priority_str <- decode.field("priority", decode.string)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use sent_at <- decode.field("sent_at", decode.optional(decode.string))

  decode.success(Broadcast(
    id: id,
    agent_id: agent_id,
    message: message,
    priority: string_to_priority(priority_str),
    status: string_to_status(status_str),
    created_at: created_at,
    sent_at: sent_at,
  ))
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
  let priority = string_to_priority(priority_str)
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO project_communications 
      (project_id, from_ai, message_type, content, priority, metadata)
      VALUES ($1, $2, 'broadcast', $3, $4, $5)
      RETURNING id
    "
    let default_project_id = "00000000-0000-0000-0000-000000000001"
    let params = [
      dynamic.string(default_project_id),
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
        Ok(result) -> {
          let broadcasts = result.rows
            |> list.map(fn(row) { decode.run(row, broadcast_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(broadcasts)
        }
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
        Ok(result) -> {
          let broadcasts = result.rows
            |> list.map(fn(row) { decode.run(row, broadcast_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(broadcasts)
        }
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
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
        COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
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
