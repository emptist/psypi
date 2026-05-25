import a_context_utils
import a_db_reader
import a_orchestrator
import gleam/int
import gleam/javascript/promise
import gleam/option
import gleam/string
import pi_extension.{
  ctx_get_context_usage_json, ctx_get_cwd, ctx_get_entries_json,
  ctx_has_pending_messages, ctx_is_idle, get_config, now_ms, notify_info,
  pi_send_message, set_config,
}

pub fn on_agent_end(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  notify_info(ctx, "[AUTONOMIC] on_agent_end FIRED — debounce elapsed, entering handler")
  case ctx_is_idle(ctx), ctx_has_pending_messages(ctx) {
    False, _ -> {
      notify_info(ctx, "[AUTONOMIC] S is not idle — clearing idle_since")
      set_config("idle_since", "0")
      promise.resolve(Ok(Nil))
    }
    True, True -> {
      notify_info(ctx, "[AUTONOMIC] S is idle but has pending messages — skipping")
      promise.resolve(Ok(Nil))
    }
    True, False -> {
      notify_info(ctx, "[AUTONOMIC] S is idle and no pending messages — checking idle_since")
      check_idle_since(ctx, pi)
    }
  }
}

fn check_idle_since(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  case get_config("idle_since") {
    option.None -> {
      // First time seeing idle — record timestamp
      let now = now_ms()
      set_config("idle_since", int.to_string(now))
      notify_info(ctx, "[AUTONOMIC] idle_since recorded: " <> int.to_string(now))
      promise.resolve(Ok(Nil))
    }
    option.Some("0") -> {
      // idle_since was cleared (S was active) — record new timestamp
      let now = now_ms()
      set_config("idle_since", int.to_string(now))
      notify_info(ctx, "[AUTONOMIC] idle_since recorded: " <> int.to_string(now))
      promise.resolve(Ok(Nil))
    }
    option.Some(idle_since_str) -> {
      case int.parse(idle_since_str) {
        Error(_) -> {
          notify_info(ctx, "[AUTONOMIC] idle_since parse error — resetting")
          set_config("idle_since", "0")
          promise.resolve(Ok(Nil))
        }
        Ok(idle_since) -> {
          let now = now_ms()
          let elapsed = now - idle_since
          // Read debounceMs from config (default 300000ms = 5min)
          case get_config("monitor_debounce_ms") {
            option.Some(debounce_str) -> {
              case int.parse(debounce_str) {
                Ok(debounce_ms) -> {
                  case elapsed >= debounce_ms {
                    True -> {
                      notify_info(ctx, "[AUTONOMIC] debounce satisfied: elapsed=" <> int.to_string(elapsed) <> "ms >= " <> int.to_string(debounce_ms) <> "ms")
                      set_config("idle_since", "0")
                      let entries_json = ctx_get_entries_json(ctx)
                      coordinate_with_s(ctx, pi, entries_json)
                    }
                    False -> {
                      notify_info(ctx, "[AUTONOMIC] debounce NOT satisfied: elapsed=" <> int.to_string(elapsed) <> "ms < " <> int.to_string(debounce_ms) <> "ms")
                      promise.resolve(Ok(Nil))
                    }
                  }
                }
                Error(_) -> {
                  // Can't parse debounce — proceed anyway
                  notify_info(ctx, "[AUTONOMIC] debounce parse error — proceeding")
                  set_config("idle_since", "0")
                  let entries_json = ctx_get_entries_json(ctx)
                  coordinate_with_s(ctx, pi, entries_json)
                }
              }
            }
            option.None -> {
              // No debounce config — use default 300000ms
              let debounce_ms = 300000
              case elapsed >= debounce_ms {
                True -> {
                  notify_info(ctx, "[AUTONOMIC] debounce satisfied (default): elapsed=" <> int.to_string(elapsed) <> "ms >= " <> int.to_string(debounce_ms) <> "ms")
                  set_config("idle_since", "0")
                  let entries_json = ctx_get_entries_json(ctx)
                  coordinate_with_s(ctx, pi, entries_json)
                }
                False -> {
                  notify_info(ctx, "[AUTONOMIC] debounce NOT satisfied (default): elapsed=" <> int.to_string(elapsed) <> "ms < " <> int.to_string(debounce_ms) <> "ms")
                  promise.resolve(Ok(Nil))
                }
              }
            }
          }
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
  let cwd = ctx_get_cwd(ctx)
  case ctx_is_idle(ctx) {
    False -> {
      notify_info(ctx, "[AUTONOMIC] S became busy during coordination — aborting")
      promise.resolve(Ok(Nil))
    }
    True ->
      promise.await(a_db_reader.is_s_still_idle(), fn(idle_result) {
        case idle_result {
          Ok(False) -> {
            notify_info(ctx, "[AUTONOMIC] S is busy (DB check) — skipping wake-up")
            promise.resolve(Ok(Nil))
          }
          _ -> coordinate_when_idle(ctx, pi, entries_json, usage_json, cwd)
        }
      })
  }
}

fn coordinate_when_idle(
  ctx: a,
  pi: b,
  entries_json: String,
  usage_json: String,
  cwd: String,
) -> promise.Promise(Result(Nil, String)) {
  case a_context_utils.parse_context_window(usage_json) {
    Error(e) -> {
      let msg =
        "[A-agentbot] <ERROR> parse_context_window failed: "
        <> e
        <> ". Fix parse_context_window in a_context_utils.gleam. Raw JSON: "
        <> string.slice(usage_json, 0, 300)
      pi_send_message(pi, "autonomic-error", msg, "persistent")
      promise.resolve(Ok(Nil))
    }
    Ok(context_window) ->
      a_orchestrator.run_a_workflow(
        ctx,
        pi,
        entries_json,
        usage_json,
        cwd,
        context_window,
      )
  }
}
