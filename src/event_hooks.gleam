import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import pi_tool_call.{type PiToolCall, PiToolCall, raw_json}

pub type EventHook {
  EventHook(
    id: String,
    event_name: String,
    hook_status: String,
    monitor_action: String,
    agentbot_action: String,
    injection_enabled: Bool,
    description: String,
    last_triggered: String,
    trigger_count: Int,
    error_count: Int,
  )
}

fn opt_to_str(opt: Option(String)) -> String {
  case opt {
    Some(s) -> s
    None -> ""
  }
}

fn event_hook_decoder() -> decode.Decoder(EventHook) {
  use id <- decode.field("id", decode.string)
  use event_name <- decode.field("event_name", decode.string)
  use hook_status <- decode.field("hook_status", decode.string)
  use monitor_action <- decode.field("monitor_action", decode.string)
  use agentbot_action <- decode.field(
    "agentbot_action",
    decode.optional(decode.string),
  )
  use injection_enabled <- decode.field("injection_enabled", decode.bool)
  use description <- decode.field("description", decode.optional(decode.string))
  use last_triggered <- decode.field(
    "last_triggered",
    decode.optional(decode.string),
  )
  use trigger_count <- decode.field("trigger_count", decode.int)
  use error_count <- decode.field("error_count", decode.int)
  decode.success(EventHook(
    id:,
    event_name:,
    hook_status:,
    monitor_action:,
    agentbot_action: opt_to_str(agentbot_action),
    injection_enabled:,
    description: opt_to_str(description),
    last_triggered: opt_to_str(last_triggered),
    trigger_count:,
    error_count:,
  ))
}

pub fn list_all_hooks() -> promise.Promise(Result(List(EventHook), db.DbError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      SELECT id::text, event_name, hook_status, monitor_action,
             COALESCE(agentbot_action, '') as agentbot_action,
             injection_enabled,
             COALESCE(description, '') as description,
             COALESCE(last_triggered::text, '') as last_triggered,
             trigger_count, error_count
      FROM psypi_event_hooks
      ORDER BY
        CASE hook_status
          WHEN 'active' THEN 1
          WHEN 'experimental' THEN 2
          WHEN 'inactive' THEN 3
          WHEN 'error' THEN 4
        END,
        event_name
    "
      promise.map(db.query(conn, sql, []), fn(result) {
        case result {
          Error(e) -> Error(e)
          Ok(query_result) -> {
            let hooks =
              query_result.rows
              |> list.map(fn(row) {
                case decode.run(row, event_hook_decoder()) {
                  Ok(h) -> [h]
                  Error(_) -> []
                }
              })
              |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
            Ok(hooks)
          }
        }
      })
    },
    fn(e) { e },
  )
}

pub fn list_active_hooks() -> promise.Promise(
  Result(List(EventHook), db.DbError),
) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      SELECT id::text, event_name, hook_status, monitor_action,
             COALESCE(agentbot_action, '') as agentbot_action,
             injection_enabled,
             COALESCE(description, '') as description,
             COALESCE(last_triggered::text, '') as last_triggered,
             trigger_count, error_count
      FROM psypi_event_hooks
      WHERE hook_status = 'active'
      ORDER BY event_name
    "
      promise.map(db.query(conn, sql, []), fn(result) {
        case result {
          Error(e) -> Error(e)
          Ok(query_result) -> {
            let hooks =
              query_result.rows
              |> list.map(fn(row) {
                case decode.run(row, event_hook_decoder()) {
                  Ok(h) -> [h]
                  Error(_) -> []
                }
              })
              |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
            Ok(hooks)
          }
        }
      })
    },
    fn(e) { e },
  )
}

pub fn record_trigger(
  event_name: String,
) -> promise.Promise(Result(Nil, db.DbError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      UPDATE psypi_event_hooks
      SET last_triggered = NOW(),
          trigger_count = trigger_count + 1,
          updated_at = NOW()
      WHERE event_name = $1
    "
      let params = [dynamic.string(event_name)]
      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Error(e) -> Error(e)
          Ok(_) -> Ok(Nil)
        }
      })
    },
    fn(e) { e },
  )
}

pub fn record_error(
  event_name: String,
  error_msg: String,
) -> promise.Promise(Result(Nil, db.DbError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      UPDATE psypi_event_hooks
      SET error_count = error_count + 1,
          last_error = $2,
          hook_status = CASE WHEN error_count >= 5 THEN 'error' ELSE hook_status END,
          updated_at = NOW()
      WHERE event_name = $1
    "
      let params = [dynamic.string(event_name), dynamic.string(error_msg)]
      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Error(e) -> Error(e)
          Ok(_) -> Ok(Nil)
        }
      })
    },
    fn(e) { e },
  )
}

pub fn set_hook_status(
  event_name: String,
  status: String,
) -> promise.Promise(Result(Nil, db.DbError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      UPDATE psypi_event_hooks
      SET hook_status = $2, updated_at = NOW()
      WHERE event_name = $1
    "
      let params = [dynamic.string(event_name), dynamic.string(status)]
      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Error(e) -> Error(e)
          Ok(_) -> Ok(Nil)
        }
      })
    },
    fn(e) { e },
  )
}

pub fn format_hooks_summary(hooks: List(EventHook)) -> String {
  hooks
  |> list.map(fn(h) {
    let status_icon = case h.hook_status {
      "active" -> "[ACTIVE]"
      "inactive" -> "[   ]"
      "error" -> "[ERR!]"
      "experimental" -> "[  ?]"
      _ -> "[???]"
    }
    let inj = case h.injection_enabled {
      True -> " 📬"
      False -> ""
    }
    status_icon
    <> " "
    <> h.event_name
    <> inj
    <> "\n    Monitor: "
    <> h.monitor_action
  })
  |> string.join("\n\n")
}

pub fn list_hooks_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-hooks-list",
    description: "List all psypi event hooks and their status (Monitor's awareness table)",
    params: [],
    module: "event_hooks",
    fn_name: "list_all_hooks",
    args: [],
    result_format: raw_json(),
  )
}

pub fn list_active_hooks_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-hooks-active",
    description: "List only active psypi event hooks (those with hook_status='active')",
    params: [],
    module: "event_hooks",
    fn_name: "list_active_hooks",
    args: [],
    result_format: raw_json(),
  )
}
