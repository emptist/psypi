import db
import gleam/dynamic.{type Dynamic}
import psypi_config
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/result
import gleam/string
import pi_extension.{
  call_monitor, ctx_get_context_usage_json, ctx_get_cwd, ctx_get_entries_json,
  ctx_has_pending_messages, ctx_is_idle, notify_info, pi_send_message,
}
import system_prompt_types.{
  type PromptComposition, High, add_component, compose, directive_component,
  new_composition, soul_component,
}

pub fn on_agent_end(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  notify_info(ctx, "[AUTONOMIC] on_agent_end FIRED — entering handler")
  case ctx_is_idle(ctx), ctx_has_pending_messages(ctx) {
    False, _ -> {
      notify_info(ctx, "[AUTONOMIC] S is not idle — clearing idle_since")
      promise.await(psypi_config.set("idle_since", "0"), fn(_) {
        promise.resolve(Ok(Nil))
      })
    }
    True, True -> {
      notify_info(ctx, "[AUTONOMIC] S is idle but has pending messages — skipping")
      promise.resolve(Ok(Nil))
    }
    True, False -> {
      notify_info(ctx, "[AUTONOMIC] S is idle — checking debounce")
      let now = current_time_ms()
      promise.await(get_idle_since(), fn(idle_result) {
        let idle_since = case idle_result {
          Ok(t) ->
            case int.parse(t) {
              Ok(n) -> n
              Error(_) -> 0
            }
          Error(_) -> 0
        }
        case idle_since {
          0 -> {
            notify_info(ctx, "[AUTONOMIC] first idle detection — recording timestamp")
            promise.await(psypi_config.set("idle_since", int.to_string(now)), fn(_) {
              promise.resolve(Ok(Nil))
            })
          }
          _ -> {
            let elapsed = now - idle_since
            promise.await(psypi_config.get_debounce_ms(), fn(debounce_result) {
              let debounce_ms = case debounce_result {
                Ok(ms) -> ms
                Error(_) -> 900000
              }
              case elapsed >= debounce_ms {
                True -> {
                  notify_info(ctx, "[AUTONOMIC] debounce satisfied, elapsed=" <> int.to_string(elapsed) <> "ms >= " <> int.to_string(debounce_ms) <> "ms")
                  let entries_json = ctx_get_entries_json(ctx)
                  coordinate_with_s(ctx, pi, entries_json)
                }
                False -> {
                  notify_info(ctx, "[AUTONOMIC] debounce NOT satisfied, elapsed=" <> int.to_string(elapsed) <> "ms < " <> int.to_string(debounce_ms) <> "ms — skipping")
                  promise.resolve(Ok(Nil))
                }
              }
            })
          }
        }
      })
    }
  }
}

fn get_idle_since() -> promise.Promise(Result(String, String)) {
  promise.map(psypi_config.get("idle_since"), fn(result) {
    case result {
      Ok(value) -> Ok(value)
      Error(_) -> Ok("0")
    }
  })
}

fn coordinate_with_s(
  ctx: a,
  pi: b,
  entries_json: String,
) -> promise.Promise(Result(Nil, String)) {
  let usage_json = ctx_get_context_usage_json(ctx)
  let cwd = ctx_get_cwd(ctx)
  promise.await(is_s_still_idle(), fn(idle_result) {
    case idle_result {
      Ok(False) -> {
        notify_info(ctx, "S is busy, skipping wake-up")
        promise.resolve(Ok(Nil))
      }
      _ -> coordinate_when_idle(ctx, pi, entries_json, usage_json, cwd)
    }
  })
}

fn coordinate_when_idle(
  ctx: a,
  pi: b,
  entries_json: String,
  usage_json: String,
  cwd: String,
) -> promise.Promise(Result(Nil, String)) {
  case parse_context_window(usage_json) {
    Error(e) -> {
      let msg =
        "[A-agentbot] <ERROR> parse_context_window failed: "
        <> e
        <> ". Fix parse_context_window in hook_on_agent_end.gleam. Raw JSON: "
        <> string.slice(usage_json, 0, 300)
      pi_send_message(pi, "autonomic-error", msg, "persistent")
      promise.resolve(Ok(Nil))
    }
    Ok(context_window) ->
      promise.await(read_soul_from_db(), fn(soul_result) {
        case soul_result {
          Error(e) -> {
            let msg =
              "[A-agentbot] <ERROR> read_soul_from_db failed: "
              <> e
              <> ". Check agent_souls table in psypi DB: SELECT * FROM agent_souls WHERE id_prefix='A'"
            pi_send_message(pi, "autonomic-error", msg, "persistent")
            promise.resolve(Ok(Nil))
          }
          Ok(soul_content) ->
            promise.await(read_directives_from_db(), fn(directives_result) {
              case directives_result {
                Error(e) -> {
                  let msg =
                    "[A-agentbot] <ERROR> read_directives_from_db failed: "
                    <> e
                    <> ". Check system_directives table: SELECT * FROM system_directives WHERE is_active=true"
                  pi_send_message(pi, "autonomic-error", msg, "persistent")
                  promise.resolve(Ok(Nil))
                }
                Ok(directives) ->
                  promise.await(read_project_state_from_db(), fn(state_result) {
                    let project_state = case state_result {
                      Ok(s) -> s
                      Error(e) -> "Failed to read project state: " <> e
                    }
                    let system_prompt =
                      compose(build_system_prompt(
                        soul_content,
                        directives,
                        context_window,
                      ))
                    let user_prompt =
                      build_user_prompt(usage_json, entries_json, cwd, project_state)
                    notify_info(ctx, "[AUTONOMIC] A thinking...")
                    promise.await(
                      call_monitor(ctx, user_prompt, system_prompt),
                      fn(monitor_result) {
                        case monitor_result {
                          Ok(response) -> {
                            notify_info(ctx, "[AUTONOMIC] sending wake-up, response length=" <> int.to_string(string.length(response)))
                            pi_send_message(
                              pi,
                              "autonomic-wakeup",
                              response,
                              "persistent",
                            )
                            notify_info(ctx, "[AUTONOMIC] wake-up sent")
                            promise.resolve(Ok(Nil))
                          }
                          Error(e) -> {
                            let msg =
                              "[A-agentbot] <ERROR> call_monitor failed: "
                              <> e
                              <> ". Check pi_extension_ffi.mjs call_monitor function and ctx.model/modelRegistry"
                            pi_send_message(pi, "autonomic-error", msg, "persistent")
                            promise.resolve(Ok(Nil))
                          }
                        }
                      },
                    )
                  })
              }
            })
        }
      })
  }
}

fn build_system_prompt(
  soul_content: String,
  directives: List(String),
  context_window: Int,
) -> PromptComposition {
  let budget = context_window / 4
  new_composition(budget)
  |> add_component(soul_component(a_identity_prompt()))
  |> add_soul_content(soul_content)
  |> add_directives(directives)
}

fn a_identity_prompt() -> String {
  "You are the Autonomic Agentbot (A-agentbot). Your ID starts with A-. "
  <> "You are NOT the Somatic Agentbot (S-agentbot). "
  <> "You are NOT the human user. "
  <> "Psypi is the personal assistant — you and S together form it.\n\n"
  <> "## Your Role\n"
  <> "Your PRIMARY job is to help S finish S's CURRENT work, not to redirect S to unrelated tasks.\n\n"
  <> "### Priority Order:\n"
  <> "1. **Inter-review**: Review S's recent work for quality, bugs, missing edge cases, better approaches.\n"
  <> "2. **Unblock**: If S is stuck, provide the specific information, context, or suggestion to unblock.\n"
  <> "3. **Continue**: Help S continue the current task — suggest next steps, point out what's missing.\n"
  <> "4. **New task ONLY if idle**: Only suggest a new task if S has NO in-progress work and is truly idle.\n\n"
  <> "### Rules:\n"
  <> "- NEVER distract S from in-progress work with unrelated tasks.\n"
  <> "- NEVER ask S to 'check' or 'review' things as a busywork task.\n"
  <> "- NEVER repeat the same directive twice.\n"
  <> "- ALWAYS check if S has a RUNNING or in-progress task before suggesting new work.\n"
  <> "- When doing inter-review, be specific: point to exact files, lines, or decisions.\n"
  <> "- Keep messages short and actionable. One focused message per turn.\n"
  <> "- Never say SKIP or that there is nothing to do.\n"
  <> "- Never introduce yourself or state your identifier.\n"
  <> "- Output ONLY the instruction for S — no preamble, no self-intro."
}

fn add_soul_content(
  comp: PromptComposition,
  content: String,
) -> PromptComposition {
  case content == "" {
    True -> comp
    False -> add_component(comp, soul_component(content))
  }
}

fn add_directives(
  comp: PromptComposition,
  directives: List(String),
) -> PromptComposition {
  list.fold(directives, comp, fn(acc, dir) {
    add_component(acc, directive_component(dir, High))
  })
}

fn build_user_prompt(
  usage_json: String,
  entries_json: String,
  cwd: String,
  project_state: String,
) -> String {
  let context_section = case cwd == "" {
    True -> ""
    False -> "Working directory: " <> cwd <> "\n"
  }
  let usage_section = case string.contains(usage_json, "tokens") {
    True -> "Context usage: " <> usage_json <> "\n"
    False -> ""
  }
  let state_section =
    "## Project State (from database):\n"
    <> project_state <> "\n\n"
  let recent_section =
    "## S's Recent Conversation (most recent at the end):\n"
    <> "Analyze what S was LAST doing. "
    <> "If S has in-progress work, help FINISH it — do NOT redirect to something else. "
    <> "If S just completed something, offer an inter-review or suggest the next logical step. "
    <> "Only propose a completely new task if S is truly idle with no in-progress work.\n\n"
    <> truncate(entries_json, 2000)
  context_section <> usage_section <> state_section <> recent_section
}

fn db_error_to_string(e: db.DbError) -> String {
  case e {
    db.ConnectionError(msg) -> "DB connection: " <> msg
    db.QueryError(msg) -> "DB query: " <> msg
  }
}

fn is_s_still_idle() -> promise.Promise(Result(Bool, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT COUNT(*) as cnt FROM agent_sessions "
        <> "WHERE status = 'alive' AND last_heartbeat > NOW() - INTERVAL '5 minutes'"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok(True)
              [row, ..] -> {
                case decode.run(row, count_decoder()) {
                  Ok(cnt) -> Ok(cnt == 0)
                  Error(_) -> Ok(True)
                }
              }
            }
        }
      })
    },
    db_error_to_string,
  )
}

fn count_decoder() -> decode.Decoder(Int) {
  use cnt <- decode.field("cnt", decode.string)
  case int.parse(cnt) {
    Ok(n) -> decode.success(n)
    Error(_) -> decode.success(0)
  }
}

fn read_soul_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT role, domain, responsibility FROM agent_souls WHERE id_prefix = 'A'"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            result.rows
            |> decode_rows(soul_responsibility_decoder())
            |> result.map(fn(entries) {
              case entries {
                [] -> Error("No AutonomicBot soul entries found")
                _ -> Ok(string.join(entries, "\n"))
              }
            })
            |> result.flatten
        }
      })
    },
    db_error_to_string,
  )
}

fn soul_responsibility_decoder() -> decode.Decoder(String) {
  use role <- decode.field("role", decode.string)
  use domain <- decode.field("domain", decode.string)
  use responsibility <- decode.field("responsibility", decode.string)
  decode.success("[" <> role <> " | " <> domain <> "] " <> responsibility)
}

fn read_directives_from_db() -> promise.Promise(Result(List(String), String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT directive_text FROM system_directives
         WHERE is_active = true
           AND (expires_at IS NULL OR expires_at > NOW())
           AND consumed_at IS NULL
         ORDER BY
           CASE priority
             WHEN 'critical' THEN 1
             WHEN 'high' THEN 2
             WHEN 'medium' THEN 3
             ELSE 4
           END,
           created_at ASC
         LIMIT 3"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) -> decode_rows(result.rows, directive_text_decoder())
        }
      })
    },
    db_error_to_string,
  )
}

fn directive_text_decoder() -> decode.Decoder(String) {
  use text <- decode.field("directive_text", decode.string)
  decode.success(text)
}

fn decode_rows(
  rows: List(Dynamic),
  decoder: decode.Decoder(a),
) -> Result(List(a), String) {
  rows
  |> list.map(fn(row) {
    decode.run(row, decoder)
    |> result.map_error(fn(e) { "decode: " <> string.inspect(e) })
  })
  |> result.all
}

fn read_project_state_from_db() -> promise.Promise(Result(String, String)) {
  let tasks_promise = read_active_tasks_no_conn()
  let issues_promise = read_open_issues_no_conn()
  promise.await(tasks_promise, fn(tasks_result) {
    let tasks_text = case tasks_result {
      Ok(t) -> t
      Error(_) -> "  (tasks unavailable)"
    }
    promise.await(issues_promise, fn(issues_result) {
      let issues_text = case issues_result {
        Ok(i) -> i
        Error(_) -> "  (issues unavailable)"
      }
      promise.resolve(Ok("ACTIVE TASKS:\n" <> tasks_text <> "\n\nOPEN ISSUES:\n" <> issues_text))
    })
  })
}

fn read_active_tasks_no_conn() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT id::text, title, status, priority, is_stuck "
        <> "FROM tasks WHERE status NOT IN ('COMPLETED','FAILED','FAKE_COMPLETE') "
        <> "ORDER BY is_stuck DESC, priority DESC, updated_at ASC LIMIT 10"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("  (none)")
              rows ->
                rows
                |> decode_rows(task_row_decoder())
                |> result.map(fn(lines) { string.join(lines, "\n") })
            }
        }
      })
    },
    fn(e) { db_error_to_string(e) },
  )
}

fn read_open_issues_no_conn() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT id::text, title, severity "
        <> "FROM issues WHERE status NOT IN ('resolved','closed') "
        <> "ORDER BY created_at DESC LIMIT 10"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            case result.rows {
              [] -> Ok("  (none)")
              rows ->
                rows
                |> decode_rows(issue_row_decoder())
                |> result.map(fn(lines) { string.join(lines, "\n") })
            }
        }
      })
    },
    fn(e) { db_error_to_string(e) },
  )
}

fn task_row_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use status <- decode.field("status", decode.string)
  use priority <- decode.field("priority", decode.string)
  use is_stuck <- decode.field("is_stuck", decode.string)
  let prefix = case is_stuck == "true" { True -> "[STUCK] " False -> "" }
  decode.success("  - " <> prefix <> "[" <> status <> " p" <> priority <> "] " <> title <> " (id: " <> id <> ")")
}

fn issue_row_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use severity <- decode.field("severity", decode.string)
  decode.success("  - [" <> severity <> "] " <> title <> " (id: " <> id <> ")")
}

fn parse_context_window(usage_json: String) -> Result(Int, String) {
  let key = "\"contextWindow\":"
  case string.contains(usage_json, "contextWindow") {
    False -> Error("contextWindow not found in usage JSON")
    True -> {
      let parts = string.split(usage_json, key)
      case parts {
        [_, rest, ..] -> {
          let digits = rest |> string.trim_start |> extract_leading_digits
          case digits == "" {
            True ->
              Error(
                "contextWindow: no digits after "
                <> key
                <> " in "
                <> string.slice(usage_json, 0, 200),
              )
            False ->
              case int.parse(digits) {
                Ok(n) -> Ok(n)
                Error(_) ->
                  Error("contextWindow: failed to parse digits: " <> digits)
              }
          }
        }
        _ ->
          Error(
            "contextWindow: split on "
            <> key
            <> " failed. JSON: "
            <> string.slice(usage_json, 0, 200),
          )
      }
    }
  }
}

fn extract_leading_digits(s: String) -> String {
  s
  |> string.to_graphemes
  |> list.take_while(is_digit)
  |> string.concat
}

fn is_digit(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}

fn current_time_ms() -> Int {
  let res = now_ms()
  case res {
    Ok(t) -> t
    Error(_) -> 0
  }
}

@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Result(Int, String)


