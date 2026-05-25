import a_context_utils
import a_db_reader
import a_orchestrator
import gleam/javascript/promise
import gleam/string
import pi_extension.{
  ctx_get_context_usage_json, ctx_get_cwd, ctx_get_entries_json,
  ctx_has_pending_messages, ctx_is_idle, notify_info, pi_send_message,
}

pub fn on_agent_end(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  notify_info(ctx, "[AUTONOMIC] on_agent_end FIRED — debounce elapsed, entering handler")
  case ctx_is_idle(ctx), ctx_has_pending_messages(ctx) {
    False, _ -> {
      notify_info(ctx, "[AUTONOMIC] S is not idle — skipping")
      promise.resolve(Ok(Nil))
    }
    True, True -> {
      notify_info(ctx, "[AUTONOMIC] S is idle but has pending messages — skipping")
      promise.resolve(Ok(Nil))
    }
    True, False -> {
      notify_info(ctx, "[AUTONOMIC] S is idle and no pending messages — proceeding")
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
