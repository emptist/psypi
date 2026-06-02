import a_db_reader
import a_prompt_builder
import gleam/javascript/promise
import gleam/string
import inter_review
import pi_extension.{call_monitor, ctx_notify, pi_send_message}
import system_prompt_types

const default_context_window: Int = 16_000

/// Handle /autonomic-listen <message> — a direct human-to-A message.
///
/// A is given the same context the autonomous hook would give it: soul (from
/// agent_souls), jobs (from agent_jobs), and project state (active tasks +
/// open issues, from the database). A reviews that context in light of the
/// human's message and produces a text response. The response is:
///   1. saved to inter_reviews (same as the autonomous path)
///   2. sent to S via pi.sendMessage with triggerTurn: true (S sees it, can act)
///
/// A has NO tool-calling capability. It does not try to query the DB, run
/// terminal commands, or call psypi-* tools. If A needs data not in the
/// prompt, it writes that need into its review and S will fetch it in the
/// next turn. This is the explicit design (migration 038, 2026-06-02).
pub fn on_autonomic_listen(
  args: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  case args == "" {
    True -> {
      ctx_notify(ctx, "Usage: /autonomic-listen <message>", "info")
      promise.resolve(Ok("Usage: /autonomic-listen <message>"))
    }
    False -> {
      ctx_notify(
        ctx,
        "[AUTONOMIC] A loading soul + jobs + project state...",
        "status",
      )
      promise.await(a_db_reader.read_soul_from_db(), fn(soul_result) {
        case soul_result {
          Error(e) -> {
            ctx_notify(
              ctx,
              "[AUTONOMIC] <ERROR> read_soul_from_db: " <> e,
              "error",
            )
            promise.resolve(Error("A failed to load soul: " <> e))
          }
          Ok(soul_content) ->
            promise.await(a_db_reader.read_a_jobs_from_db(), fn(jobs_result) {
              case jobs_result {
                Error(e) -> {
                  ctx_notify(
                    ctx,
                    "[AUTONOMIC] <ERROR> read_a_jobs_from_db: " <> e,
                    "error",
                  )
                  promise.resolve(Error("A failed to load jobs: " <> e))
                }
                Ok(a_jobs) ->
                  promise.await(
                    a_db_reader.read_project_state_from_db(),
                    fn(state_result) {
                      let project_state = case state_result {
                        Ok(s) -> s
                        Error(e) -> "Failed to read project state: " <> e
                      }
                      let _ =
                        ctx_notify(
                          ctx,
                          "[AUTONOMIC] A thinking about human message...",
                          "status",
                        )
                      let system_prompt =
                        system_prompt_types.compose(
                          a_prompt_builder.build_system_prompt(
                            soul_content,
                            a_jobs,
                            default_context_window,
                          ),
                        )
                      let user_prompt = build_user_prompt(args, project_state)
                      promise.await(
                        call_monitor(ctx, user_prompt, system_prompt),
                        fn(result) {
                          case result {
                            Ok(response) ->
                              finish_autonomic_listen(response, ctx, pi)
                            Error(e) -> {
                              ctx_notify(
                                ctx,
                                "[AUTONOMIC] <ERROR> call_monitor: " <> e,
                                "error",
                              )
                              promise.resolve(Error(
                                "A failed to process: " <> e,
                              ))
                            }
                          }
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
}

fn build_user_prompt(human_message: String, project_state: String) -> String {
  "## Mode: direct human message to A
" <> "The human is sending A a direct message (via /autonomic-listen). This is NOT the autonomous debounce path. There is no S session that just ended. A is asked to think and respond.\n\n" <> "## Human message\n" <> human_message <> "\n\n" <> "## Project State (from database, preloaded — A cannot query DB directly)\n" <> project_state <> "\n\n" <> "## A's expected response format\n" <> "Reply as plain text. Do NOT emit any tool-call XML (no <longcat_tool_call> or similar). A has no tool-calling capability.\n" <> "If the human is asking for an inter-review, structure the response as a normal inter-review: summary, score, findings, suggested next steps.\n" <> "If the human is asking A to act on something, A's role is to ask S to do it. A cannot do it directly. Compose a clear request for S in plain text.\n" <> "If A needs data that is not in the project_state above, write the request as a finding (\"S, please run SELECT ...\") and S will fetch it.\n"
}

fn inter_review_error_to_string(e: inter_review.InterReviewError) -> String {
  case e {
    inter_review.ConnectionError(msg) -> "DB connection: " <> msg
    inter_review.QueryError(msg) -> "DB query: " <> msg
    inter_review.DecodeError(msg) -> "DB decode: " <> msg
  }
}

fn finish_autonomic_listen(
  response: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  let _ =
    ctx_notify(ctx, "[AUTONOMIC] Saving inter-review to database...", "status")
  let score = a_prompt_builder.parse_review_score(response)
  promise.await(
    inter_review.save("A-agentbot", response, score, "[]", "[]"),
    fn(save_result) {
      let tagged = case
        string.starts_with(response, "[A]")
        || string.starts_with(response, "[A-agentbot]")
      {
        True -> response
        False -> "[A-agentbot] " <> response
      }
      case save_result {
        Ok(review_id) -> {
          let msg_with_id =
            tagged <> "\n\n[inter-review id: " <> review_id <> "]"
          pi_send_message(
            pi,
            "autonomic-wakeup",
            msg_with_id,
            "persistent",
            True,
            "followUp",
          )
          ctx_notify(
            ctx,
            "[AUTONOMIC] wake-up sent (review " <> review_id <> ")",
            "info",
          )
          promise.resolve(Ok(
            "A processed the message and sent to S. Inter-review "
            <> review_id
            <> " saved.",
          ))
        }
        Error(save_err) -> {
          let save_err_str = inter_review_error_to_string(save_err)
          ctx_notify(
            ctx,
            "[AUTONOMIC] save error: "
              <> save_err_str
              <> " (sending without save)",
            "error",
          )
          pi_send_message(
            pi,
            "autonomic-wakeup",
            tagged,
            "persistent",
            True,
            "followUp",
          )
          ctx_notify(ctx, "[AUTONOMIC] wake-up sent (save failed)", "info")
          promise.resolve(Ok(
            "A processed the message and sent to S. (Save failed: "
            <> save_err_str
            <> ")",
          ))
        }
      }
    },
  )
}
