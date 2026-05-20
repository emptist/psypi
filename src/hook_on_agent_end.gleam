import db
import file_utils
import gleam/dynamic.{type Dynamic}
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
  case ctx_is_idle(ctx), ctx_has_pending_messages(ctx) {
    False, _ -> promise.resolve(Ok(Nil))
    True, True -> promise.resolve(Ok(Nil))
    True, False -> {
      notify_info(ctx, "[AUTONOMIC] S is idle")
      let entries_json = ctx_get_entries_json(ctx)
      coordinate_with_s(ctx, pi, entries_json)
    }
  }
}

fn coordinate_with_s(
  ctx: a,
  pi: b,
  entries_json: String,
) -> promise.Promise(Result(Nil, String)) {
  let usage_json = ctx_get_context_usage_json(ctx)
  let cwd = ctx_get_cwd(ctx)
  case parse_context_window(usage_json) {
    Error(e) -> {
      let msg =
        "[A-agentbot] <ERROR> parse_context_window failed: "
        <> e
        <> ". Fix parse_context_window in hook_on_agent_end.gleam. Raw JSON: "
        <> string.slice(usage_json, 0, 300)
      notify_info(ctx, "[AUTONOMIC] " <> msg)
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
              <> ". Check souls table in psypi DB: SELECT * FROM souls WHERE name='Monitor'"
            notify_info(ctx, "[AUTONOMIC] " <> msg)
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
                  notify_info(ctx, "[AUTONOMIC] " <> msg)
                  pi_send_message(pi, "autonomic-error", msg, "persistent")
                  promise.resolve(Ok(Nil))
                }
                Ok(directives) -> {
                  let system_prompt =
                    compose(build_system_prompt(
                      soul_content,
                      directives,
                      context_window,
                    ))
                  let user_prompt =
                    build_user_prompt(usage_json, entries_json, cwd)
                  notify_info(ctx, "[AUTONOMIC] A thinking...")
                  promise.await(
                    call_monitor(ctx, user_prompt, system_prompt),
                    fn(monitor_result) {
                      case monitor_result {
                        Ok(response) -> {
                          // Deduplication: skip if same as last wake-up
                          promise.await(get_last_wakeup(), fn(last_result) {
                            let last_msg = case last_result {
                              Ok(msg) -> msg
                              Error(_) -> ""
                            }
                            case last_msg == response {
                              True -> {
                                notify_info(ctx, "[AUTONOMIC] skipping duplicate wake-up")
                                promise.resolve(Ok(Nil))
                              }
                              False -> {
                                // Store new message and send
                                promise.await(set_last_wakeup(response), fn(_) {
                                  pi_send_message(
                                    pi,
                                    "autonomic-wakeup",
                                    response,
                                    "persistent",
                                  )
                                  notify_info(ctx, "[AUTONOMIC] wake-up sent")
                                  promise.resolve(Ok(Nil))
                                })
                              }
                            }
                          })
                        }
                        Error(e) -> {
                          let msg =
                            "[A-agentbot] <ERROR> call_monitor failed: "
                            <> e
                            <> ". Check pi_extension_ffi.mjs call_monitor function and ctx.model/modelRegistry"
                          notify_info(ctx, "[AUTONOMIC] " <> msg)
                          pi_send_message(
                            pi,
                            "autonomic-error",
                            msg,
                            "persistent",
                          )
                          promise.resolve(Ok(Nil))
                        }
                      }
                    },
                  )
                }
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
  <> "Psypi is the personal assistant — you and S together form it. "
  <> "You observe, analyze, and direct S on what to work on next. "
  <> "Never say SKIP or that there is nothing to do. "
  <> "Never introduce yourself or state your identifier. "
  <> "Your output is sent directly to S as a task instruction. "
  <> "Output ONLY the task instruction for S — no preamble, no self-intro. "
  <> "Be brief and specific. One task per message. "
  <> "Always output a clear text instruction for S — do not only think."
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
) -> String {
  let context_section = case cwd == "" {
    True -> ""
    False -> "Working directory: " <> cwd <> "\n"
  }
  let usage_section = case string.contains(usage_json, "tokens") {
    True -> "Context usage: " <> usage_json <> "\n"
    False -> ""
  }
  let recent_section =
    "Below is S's recent conversation. You are A, not S. "
    <> "Do NOT continue S's conversation. "
    <> "Analyze what S just did and tell S what to do next.\n\n"
    <> truncate(entries_json, 2000)
  context_section <> usage_section <> recent_section
}

fn db_error_to_string(e: db.DbError) -> String {
  case e {
    db.ConnectionError(msg) -> "DB connection: " <> msg
    db.QueryError(msg) -> "DB query: " <> msg
  }
}

fn read_soul_from_db() -> promise.Promise(Result(String, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT content FROM souls WHERE name = 'Monitor' AND agent_id LIKE 'A-%' LIMIT 1"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) ->
            result.rows
            |> decode_rows(soul_content_decoder())
            |> result.map(fn(entries) {
              case entries {
                [] -> Error("No Monitor soul entries found")
                [content, ..] -> Ok(content)
              }
            })
            |> result.flatten
        }
      })
    },
    db_error_to_string,
  )
}

fn soul_content_decoder() -> decode.Decoder(String) {
  use content <- decode.field("content", decode.string)
  decode.success(content)
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

// Deduplication: track last wake-up message to avoid duplicates
fn get_last_wakeup() -> promise.Promise(Result(String, String)) {
  let path = ".psypi_last_wakeup"
  case file_utils.read_file(path) {
    Ok(content) -> promise.resolve(Ok(content))
    Error(_) -> promise.resolve(Ok(""))
  }
}

fn set_last_wakeup(msg: String) -> promise.Promise(Result(Nil, String)) {
  let path = ".psypi_last_wakeup"
  case file_utils.write_file(path, msg) {
    Ok(_) -> promise.resolve(Ok(Nil))
    Error(_) -> promise.resolve(Error("Failed to write last wakeup"))
  }
}
