import a_db_reader
import a_prompt_builder
import gleam/int
import gleam/javascript/promise
import gleam/string
import pi_extension.{
  call_monitor, ctx_is_idle, exec_sync, notify_info,
  now_ms, pi_send_message,
}
import psypi_config
import system_prompt_types.{compose}

pub fn run_a_workflow(
  ctx: a,
  pi: b,
  entries_json: String,
  usage_json: String,
  cwd: String,
  context_window: Int,
) -> promise.Promise(Result(Nil, String)) {
  run_full_workflow(ctx, pi, entries_json, usage_json, cwd, context_window)
}

fn run_full_workflow(
  ctx: a,
  pi: b,
  entries_json: String,
  usage_json: String,
  cwd: String,
  context_window: Int,
) -> promise.Promise(Result(Nil, String)) {
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
                        compose(a_prompt_builder.build_system_prompt(
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
                      notify_info(ctx, "[AUTONOMIC] A thinking...")
                      promise.await(
                        call_monitor(ctx, user_prompt, system_prompt),
                        fn(monitor_result) {
                          handle_monitor_response(ctx, pi, monitor_result)
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

fn get_recent_commits(since_timestamp: String) -> String {
  let cmd = case since_timestamp {
    "" -> "git log --oneline -20"
    ts -> {
      let secs = case int.parse(ts) {
        Ok(ms) -> int.to_string(ms / 1000)
        Error(_) -> "0"
      }
      "git log --oneline --since=\"@"
      <> secs
      <> " seconds\""
    }
  }
  case exec_sync(cmd) {
    Ok(out) ->
      case string.length(out) > 4000 {
        True -> string.slice(out, 0, 4000)
        False -> out
      }
    Error(_) -> ""
  }
}

fn handle_monitor_response(
  ctx: a,
  pi: b,
  monitor_result: Result(String, String),
) -> promise.Promise(Result(Nil, String)) {
  case monitor_result {
    Ok(response) -> {
      case ctx_is_idle(ctx) {
        False -> {
          notify_info(
            ctx,
            "[AUTONOMIC] S became busy during A's thinking — aborting wake-up",
          )
          promise.resolve(Ok(Nil))
        }
        True -> {
          let now = now_ms()
          let _ = psypi_config.set("last_a_session_at", int.to_string(now))
          notify_info(
            ctx,
            "[AUTONOMIC] sending wake-up, response length="
              <> int.to_string(string.length(response)),
          )
          pi_send_message(pi, "autonomic-wakeup", response, "persistent")
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
}
