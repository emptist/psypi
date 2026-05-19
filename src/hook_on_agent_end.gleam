import db
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
  case ctx_is_idle(ctx) {
    False -> {
      promise.resolve(Ok(Nil))
    }
    True -> {
      notify_info(ctx, "[AUTONOMIC] S is idle")
      case ctx_has_pending_messages(ctx) {
        True -> {
          promise.resolve(Ok(Nil))
        }
        False -> {
          let entries_json = ctx_get_entries_json(ctx)
          coordinate_with_s(ctx, pi, entries_json)
        }
      }
    }
  }
}

fn coordinate_with_s(
  ctx: a,
  pi: b,
  entries_json: String,
) -> promise.Promise(Result(Nil, String)) {
  let usage_json = ctx_get_context_usage_json(ctx)
  let context_window = parse_context_window(usage_json)
  case context_window == 0 {
    True -> {
      notify_info(
        ctx,
        "[AUTONOMIC] <ERROR> context_window unavailable, cannot coordinate",
      )
      promise.resolve(Ok(Nil))
    }
    False ->
      promise.await(read_soul_from_db(), fn(soul_result) {
        let soul_content = case soul_result {
          Ok(content) -> content
          Error(e) -> {
            notify_info(ctx, "[AUTONOMIC] <ERROR> read_soul: " <> e)
            ""
          }
        }
        promise.await(read_directives_from_db(), fn(directives_result) {
          let directives = case directives_result {
            Ok(dirs) -> dirs
            Error(e) -> {
              notify_info(ctx, "[AUTONOMIC] <ERROR> read_directives: " <> e)
              []
            }
          }
          let composition =
            build_system_prompt(soul_content, directives, context_window)
          let system_prompt = compose(composition)
          let user_prompt = build_user_prompt(usage_json, entries_json, ctx)
          notify_info(ctx, "[AUTONOMIC] A thinking...")
          promise.await(
            call_monitor(ctx, user_prompt, system_prompt),
            fn(monitor_result) {
              case monitor_result {
                Ok(response) -> {
                  let message = case
                    string.starts_with(response, "[A-agentbot]")
                  {
                    True -> response
                    False -> "[A-agentbot] " <> response
                  }
                  pi_send_message(pi, "autonomic-wakeup", message, "persistent")
                  notify_info(ctx, "[AUTONOMIC] wake-up sent")
                  promise.resolve(Ok(Nil))
                }
                Error(e) -> {
                  notify_info(ctx, "[AUTONOMIC] <ERROR> call_monitor: " <> e)
                  promise.resolve(Ok(Nil))
                }
              }
            },
          )
        })
      })
  }
}

fn build_system_prompt(
  soul_content: String,
  directives: List(String),
  context_window: Int,
) -> PromptComposition {
  let budget = context_window / 4
  let comp = new_composition(budget)
  let identity_comp =
    add_component(
      comp,
      soul_component(
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
        <> "Always output a clear text instruction for S — do not only think.",
      ),
    )
  let soul_comp = case soul_content == "" {
    True -> identity_comp
    False -> add_component(identity_comp, soul_component(soul_content))
  }
  list.fold(directives, soul_comp, fn(acc, dir) {
    add_component(acc, directive_component(dir, High))
  })
}

fn build_user_prompt(
  usage_json: String,
  entries_json: String,
  ctx: a,
) -> String {
  let usage_section = case string.contains(usage_json, "tokens") {
    True -> usage_json
    False -> ""
  }
  let recent = truncate(entries_json, 2000)
  let cwd = ctx_get_cwd(ctx)
  let cwd_section = case cwd == "" {
    True -> ""
    False -> "Working directory: " <> cwd
  }
  let base = case usage_section == "" {
    True -> recent
    False -> usage_section <> "\n" <> recent
  }
  case cwd_section == "" {
    True -> base
    False -> cwd_section <> "\n" <> base
  }
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
        "SELECT role, responsibility, domain FROM soul WHERE is_active = true AND role = 'Monitor' ORDER BY priority"
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_string(e))
          Ok(result) -> {
            let entries =
              result.rows
              |> list.map(fn(row) {
                case decode.run(row, soul_entry_decoder()) {
                  Ok(entry) -> Ok([entry])
                  Error(e) -> Error("soul decode: " <> string.inspect(e))
                }
              })
              |> list.fold(Ok([]), fn(acc, lst) {
                case acc, lst {
                  Ok(a), Ok(b) -> Ok(list.append(a, b))
                  Error(e), _ -> Error(e)
                  _, Error(e) -> Error(e)
                }
              })
            case entries {
              Ok(es) ->
                case es {
                  [] -> Error("No Monitor soul entries found")
                  _ -> Ok(string.join(es, "\n"))
                }
              Error(e) -> Error(e)
            }
          }
        }
      })
    },
    db_error_to_string,
  )
}

fn soul_entry_decoder() -> decode.Decoder(String) {
  use role <- decode.field("role", decode.string)
  use responsibility <- decode.field("responsibility", decode.string)
  use domain <- decode.field("domain", decode.string)
  decode.success(role <> " | " <> domain <> ": " <> responsibility)
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
          Ok(result) -> {
            let directives =
              result.rows
              |> list.map(fn(row) {
                case decode.run(row, directive_text_decoder()) {
                  Ok(text) -> Ok([text])
                  Error(e) -> Error("directive decode: " <> string.inspect(e))
                }
              })
              |> list.fold(Ok([]), fn(acc, lst) {
                case acc, lst {
                  Ok(a), Ok(b) -> Ok(list.append(a, b))
                  Error(e), _ -> Error(e)
                  _, Error(e) -> Error(e)
                }
              })
            case directives {
              Ok(dirs) -> Ok(dirs)
              Error(e) -> Error(e)
            }
          }
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

fn parse_context_window(usage_json: String) -> Int {
  case string.contains(usage_json, "contextWindow") {
    False -> 0
    True -> {
      let parts = string.split(usage_json, "contextWindow")
      case parts {
        [_, rest, ..] -> {
          let after = string.trim_start(rest)
          case string.starts_with(after, ":") {
            False -> 0
            True -> {
              let num_str =
                after
                |> string.drop_start(1)
                |> string.trim_start
              extract_leading_digits(num_str)
            }
          }
        }
        _ -> 0
      }
    }
  }
}

fn extract_leading_digits(s: String) -> Int {
  s
  |> string.to_graphemes
  |> list.take_while(is_digit)
  |> string.concat
  |> int.parse
  |> result.unwrap(0)
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
