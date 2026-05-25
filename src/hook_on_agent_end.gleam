import a_context_utils
import a_db_reader
import a_prompt_builder
import gleam/int
import gleam/javascript/promise
import gleam/string
import pi_extension.{
  call_monitor, ctx_get_context_usage_json, ctx_get_cwd, ctx_get_entries_json,
  ctx_has_pending_messages, ctx_is_idle, notify_info, pi_send_message,
}
import system_prompt_types.{compose}

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
      promise.await(a_db_reader.read_soul_from_db(), fn(soul_result) {
        case soul_result {
          Error(e) -> {
            let msg =
              "[A-agentbot] <ERROR> read_soul_from_db failed: "
              <> e
              <> ". Check agent_souls table: SELECT * FROM agent_souls WHERE id_prefix='A'"
            pi_send_message(pi, "autonomic-error", msg, "persistent")
            promise.resolve(Ok(Nil))
          }
          Ok(soul_content) ->
            promise.await(a_db_reader.read_a_jobs_from_db(), fn(jobs_result) {
              case jobs_result {
                Error(e) -> {
                  let msg =
                    "[A-agentbot] <ERROR> read_a_jobs_from_db failed: "
                    <> e
                    <> ". Check agent_jobs table: SELECT j.* FROM agent_jobs j JOIN agent_souls s ON j.soul_id = s.id WHERE s.id_prefix='A'"
                  pi_send_message(pi, "autonomic-error", msg, "persistent")
                  promise.resolve(Ok(Nil))
                }
                Ok(a_jobs) ->
                  promise.await(a_db_reader.read_project_state_from_db(), fn(state_result) {
                    let project_state = case state_result {
                      Ok(s) -> s
                      Error(e) -> "Failed to read project state: " <> e
                    }
                    let system_prompt =
                      compose(a_prompt_builder.build_system_prompt(
                        soul_content,
                        a_jobs,
                        context_window,
                      ))
                    let user_prompt =
                      a_prompt_builder.build_user_prompt(usage_json, entries_json, cwd, project_state)
                    notify_info(ctx, "[AUTONOMIC] A thinking...")
                    promise.await(
                      call_monitor(ctx, user_prompt, system_prompt),
                      fn(monitor_result) {
                        case monitor_result {
                          Ok(response) -> {
                            case ctx_is_idle(ctx) {
                              False -> {
                                notify_info(ctx, "[AUTONOMIC] S became busy during A's thinking — aborting wake-up")
                                promise.resolve(Ok(Nil))
                              }
                              True -> {
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
                            }
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
