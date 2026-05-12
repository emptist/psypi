import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db

pub type MonitorModel {
  MonitorModel(
    provider: String,
    model: Option(String),
  )
}

pub type MonitorError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn db_error_to_monitor_error(e: db.DbError) -> MonitorError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn monitor_model_decoder() -> decode.Decoder(MonitorModel) {
  use provider <- decode.field("provider", decode.string)
  use model <- decode.field("model", decode.optional(decode.string))
  decode.success(MonitorModel(provider:, model:))
}

/// Get the current Monitor AI model from database
pub fn get_model() -> promise.Promise(Result(Option(MonitorModel), MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT provider, model 
      FROM provider_api_keys 
      WHERE status = 'in_use' 
      LIMIT 1
    "
    let params: List(dynamic.Dynamic) = []

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Ok(None)
            [row, ..] -> {
              case decode.run(row, monitor_model_decoder()) {
                Ok(m) -> Ok(Some(m))
                Error(_) -> Error(DecodeError("Failed to decode monitor model"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Record current model being used (called on session start)
pub fn record_current_model(model_name: String) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO activity_log (agent_id, activity, context)
      VALUES ($1, $2, $3)
    "
    let params = [
      dynamic.string("system"),
      dynamic.string("model_used"),
      dynamic.string("{\"model\": \"" <> model_name <> "\"}"),
    ]

    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_monitor_error(e))
      }
    })
  }, db_error_to_monitor_error)
}

/// Set the Monitor AI model in database
pub fn set_model(
  provider: String,
  model: Option(String),
) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    let reset_sql = "UPDATE provider_api_keys SET status = 'not_used'"
    let reset_params: List(dynamic.Dynamic) = []

    promise.await(db.query(conn, reset_sql, reset_params), fn(reset_result) {
      case reset_result {
        Error(e) -> promise.resolve(Error(db_error_to_monitor_error(e)))
        Ok(_) -> {
          let update_sql = case model {
            Some(_) -> 
              "UPDATE provider_api_keys SET status = 'in_use', model = $2 WHERE provider = $1"
            None ->
              "UPDATE provider_api_keys SET status = 'in_use' WHERE provider = $1"
          }
          let update_params = case model {
            Some(m) -> [dynamic.string(provider), dynamic.string(m)]
            None -> [dynamic.string(provider)]
          }

          promise.await(db.query(conn, update_sql, update_params), fn(update_result) {
            case update_result {
              Error(e) -> promise.resolve(Error(db_error_to_monitor_error(e)))
              Ok(_) -> promise.resolve(Ok(Nil))
            }
          })
        }
      }
    })
  }, db_error_to_monitor_error)
}

// ---------------------------------------------------------------------------
// Notifications for Worker communication
// ---------------------------------------------------------------------------

pub type Notification {
  Notification(
    id: String,
    agent_id: String,
    priority: String,
    title: String,
    body: String,
    created_at: String,
    read_at: Option(String),
  )
}

fn notification_decoder() -> decode.Decoder(Notification) {
  use id <- decode.field("id", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use priority <- decode.field("priority", decode.string)
  use title <- decode.field("title", decode.string)
  use body <- decode.field("body", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use read_at <- decode.field("read_at", decode.optional(decode.string))
  decode.success(Notification(id:, agent_id:, priority:, title:, body:, created_at:, read_at:))
}

fn id_only_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

/// Get pending notifications for an agent (unread, ordered by priority/date)
pub fn get_pending_notifications(
  agent_id: String,
) -> promise.Promise(Result(List(Notification), MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, agent_id, priority, title, body, 
             created_at::text as created_at, read_at::text as read_at
      FROM notifications 
      WHERE agent_id = $1 AND read_at IS NULL
      ORDER BY 
        CASE priority 
          WHEN 'critical' THEN 1 
          WHEN 'high' THEN 2 
          WHEN 'medium' THEN 3 
          ELSE 4 
        END,
        created_at ASC
      LIMIT 10
    "
    let params = [dynamic.string(agent_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          let notifs = result.rows
            |> list.map(fn(row) {
              case decode.run(row, notification_decoder()) {
                Ok(n) -> [n]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(notifs)
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Create a notification for an agent (Monitor → Worker communication)
pub fn create_notification(
  agent_id: String,
  priority: String,
  title: String,
  body: String,
) -> promise.Promise(Result(String, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO notifications (agent_id, priority, title, body)
      VALUES ($1, $2, $3, $4)
      RETURNING id::text
    "
    let params = [
      dynamic.string(agent_id),
      dynamic.string(priority),
      dynamic.string(title),
      dynamic.string(body),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_only_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode notification id"))
              }
            }
            _ -> Error(NotFound("No ID returned"))
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Mark notifications as read for an agent
pub fn mark_notifications_read(
  agent_id: String,
) -> promise.Promise(Result(Int, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE notifications 
      SET read_at = NOW() 
      WHERE agent_id = $1 AND read_at IS NULL
      RETURNING id
    "
    let params = [dynamic.string(agent_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> Ok(list.length(result.rows))
      }
    })
  }, db_error_to_monitor_error)
}
