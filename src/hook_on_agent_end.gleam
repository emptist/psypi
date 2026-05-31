import a_context_utils
import a_db_reader
import a_prompt_builder
import gleam/int
import gleam/javascript/promise
import gleam/string
import pi_extension.{
  call_monitor, ctx_get_context_usage_json, ctx_get_cwd,
  ctx_get_entries_json, ctx_is_idle, now_ms, pi_send_message,
}
import psypi_config
import system_prompt_types

pub fn on_agent_end(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  case ctx_is_idle(ctx) {
    False -> promise.resolve(Ok(Nil))
    True ->
      case ctx_has_pending_messages(ctx) {
        True -> promise.resolve(Ok(Nil))
        False -> run_a_bot(ctx, pi)
      }
  }
}

fn ctx_has_pending_messages(ctx: a) -> Bool {
  pi_extension.ctx_has_pending_messages(ctx)
}

fn run_a_bot(ctx: a, pi: b) -> promise.Promise(Result(Nil, String)) {
  let entries_json = ctx_get_entries_json(ctx)
  let usage_json = ctx_get_context_usage_json(ctx)
  let cwd = ctx_get_cwd(ctx)
  case a_context_utils.parse_context_window(usage_json) {
    Error(e) -> {
      let msg =
        "[A-agentbot] <ERROR> parse_context_window: "
        <> e
        <> ". Raw JSON: "
        <> string.slice(usage_json, 0, 300)
      pi_send_message(pi, "autonomic-error", msg, "persistent")
      promise.resolve(Ok(Nil))
    }
    Ok(context_window) ->
      promise.await(a_db_reader.read_soul_from_db(), fn(soul_result) {
        case soul_result {
          Error(e) -> {
            let msg =
              "[A-agentbot] <ERROR> read_soul_from_db: "
              <> e
            pi_send_message(pi, "autonomic-error", msg, "persistent")
            promise.resolve(Ok(Nil))
          }
          Ok(soul_content) ->
            promise.await(a_db_reader.read_a_jobs_from_db(), fn(jobs_result) {
              case jobs_result {
                Error(e) -> {
                  let msg =
                    "[A-agentbot] <ERROR> read_a_jobs_from_db: "
                    <> e
                  pi_send_message(pi, "autonomic-error", msg, "persistent")
                  promise.resolve(Ok(Nil))
                }
                Ok(a_jobs) ->
                  promise.await(
                    a_db_reader.read_project_state_from_db(),
                    fn(state_result) {
                      let project_state = case state_result {
                        Ok(s) -> s
                        Error(e) -> "Failed to read project state: " <> e
                      }
                      promise.await(
                        a_db_reader.get_last_a_session_at(),
                        fn(last_session_result) {
                          let last_session = case last_session_result {
                            Ok(ts) -> ts
                            Error(_) -> ""
                          }
                          let commit_info = get_recent_commits(last_session)
                          let system_prompt =
                            system_prompt_types.compose(a_prompt_builder.build_system_prompt(
                              soul_content,
                              a_jobs,
                              context_window,
                            ))
                          let user_prompt =
                            a_prompt_builder.build_user_prompt(
                              usage_json,
                              entries_json,
                              cwd,
                              project_state,
                              commit_info,
                            )
                          promise.await(
                            call_monitor(ctx, user_prompt, system_prompt),
                            fn(monitor_result) {
                              case monitor_result {
                                Ok(response) -> {
                                  case ctx_is_idle(ctx) {
                                    True -> {
                                      let _ = psypi_config.set(
                                        "last_a_session_at",
                                        int.to_string(now_ms()),
                                      )
                                      pi_send_message(
                                        pi,
                                        "autonomic-wakeup",
                                        response,
                                        "persistent",
                                      )
                                    }
                                    False -> Nil
                                  }
                                  promise.resolve(Ok(Nil))
                                }
                                Error(e) -> {
                                  pi_send_message(
                                    pi,
                                    "autonomic-error",
                                    "[A-agentbot] <ERROR> call_monitor: " <> e,
                                    "persistent",
                                  )
                                  promise.resolve(Ok(Nil))
                                }
                              }
                            },
                          )
                        },
                      )
                    },
                  )
              }
            })
        }
      })
  }
}

fn get_recent_commits(since_timestamp: String) -> String {
  let cmd = case since_timestamp {
    "" -> "git log --oneline -20"
    ts -> {
      let secs = case int.parse(ts) {
        Ok(ms) -> int.to_string(ms / 1000)
        Error(_) -> "0"
      }
      "git log --oneline --since=\"@" <> secs <> " seconds\""
    }
  }
  case pi_extension.exec_sync(cmd) {
    Ok(out) ->
      case string.length(out) > 4000 {
        True -> string.slice(out, 0, 4000)
        False -> out
      }
    Error(_) -> ""
  }
}
