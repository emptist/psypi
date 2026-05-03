import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi_cli/db

pub type BroadcastPriority {
  Low
  Normal
  High
  Urgent
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

fn priority_to_int(p: BroadcastPriority) -> Int {
  case p {
    Low -> 0
    Normal -> 1
    High -> 2
    Urgent -> 3
  }
}

fn int_to_priority(i: Int) -> BroadcastPriority {
  case i {
    3 -> Urgent
    2 -> High
    1 -> Normal
    _ -> Low
  }
}

fn status_to_string(s: BroadcastStatus) -> String {
  case s {
    Pending -> "pending"
    Sent -> "sent"
    Failed -> "failed"
    Cancelled -> "cancelled"
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
  use priority_int <- decode.field("priority", decode.int)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use sent_at <- decode.field("sent_at", decode.optional(decode.string))

  decode.success(Broadcast(
    id: id,
    agent_id: agent_id,
    message: message,
    priority: int_to_priority(priority_int),
    status: string_to_status(status_str),
    created_at: created_at,
    sent_at: sent_at,
  ))
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

pub fn send(
  agent_id: String,
  message: String,
  priority: BroadcastPriority,
) -> promise.Promise(Result(String, BroadcastError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = "
          INSERT INTO broadcasts (agent_id, message, priority, status)
          VALUES ($1, $2, $3, 'sent')
          RETURNING id
        "
        let params = [
          dynamic.string(agent_id),
          dynamic.string(message),
          dynamic.int(priority_to_int(priority)),
        ]

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              case result.rows {
                [row, ..] -> {
                  case decode.run(row, id_decoder()) {
                    Ok(id) -> promise.resolve(Ok(id))
                    Error(_) -> promise.resolve(Error(DecodeError("Failed to decode id")))
                  }
                }
                _ -> promise.resolve(Error(NotFound("No id returned")))
              }
            }
          }
        })
      }
    }
  })
}

pub fn list(
  agent_id: Option(String),
  limit: Int,
) -> promise.Promise(Result(List(Broadcast), BroadcastError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = case agent_id {
          Some(_) -> "
            SELECT id, agent_id, message, priority, status, created_at::text, sent_at::text
            FROM broadcasts
            WHERE agent_id = $1
            ORDER BY created_at DESC
            LIMIT $2
          "
          None -> "
            SELECT id, agent_id, message, priority, status, created_at::text, sent_at::text
            FROM broadcasts
            ORDER BY created_at DESC
            LIMIT $1
          "
        }

        let params = case agent_id {
          Some(id) -> [dynamic.string(id), dynamic.int(limit)]
          None -> [dynamic.int(limit)]
        }

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              let broadcasts = result.rows
                |> list.map(fn(row) { decode.run(row, broadcast_decoder()) })
                |> list.filter_map(fn(r) { r })

              promise.resolve(Ok(broadcasts))
            }
          }
        })
      }
    }
  })
}

pub fn get_recent(
  agent_id: String,
  count: Int,
) -> promise.Promise(Result(List(Broadcast), BroadcastError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = "
          SELECT id, agent_id, message, priority, status, created_at::text, sent_at::text
          FROM broadcasts
          WHERE agent_id = $1
          ORDER BY created_at DESC
          LIMIT $2
        "
        let params = [dynamic.string(agent_id), dynamic.int(count)]

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              let broadcasts = result.rows
                |> list.map(fn(row) { decode.run(row, broadcast_decoder()) })
                |> list.filter_map(fn(r) { r })

              promise.resolve(Ok(broadcasts))
            }
          }
        })
      }
    }
  })
}

pub fn stats(
  agent_id: String,
) -> promise.Promise(Result(#(Int, Int, Int), BroadcastError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = "
          SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
            COUNT(*) FILTER (WHERE priority >= 2) as high_priority_count
          FROM broadcasts
          WHERE agent_id = $1
        "
        let params = [dynamic.string(agent_id)]

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              case result.rows {
                [row, ..] -> {
                  use total <- decode.field("total", decode.int)
                  use sent_count <- decode.field("sent_count", decode.int)
                  use high_priority_count <- decode.field("high_priority_count", decode.int)
                  case decode.run(row, decode.success(#(total, sent_count, high_priority_count))) {
                    Ok(stats) -> promise.resolve(Ok(stats))
                    Error(_) -> promise.resolve(Error(DecodeError("Failed to decode stats")))
                  }
                }
                _ -> promise.resolve(Error(NotFound("No stats returned")))
              }
            }
          }
        })
      }
    }
  })
}
