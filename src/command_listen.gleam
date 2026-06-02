import a_db_reader
import a_prompt_builder
import gleam/javascript/promise
import gleam/string
import inter_review
import pi_extension.{call_monitor, ctx_notify, pi_send_message}
import system_prompt_types

const default_context_window: Int = 16_000

/// Handle /autonomic-listen <message> — a debug-only tool for peeking at
/// A's environment.
///
/// This is NOT a normal user-facing command. In normal operation psypi runs
/// without human involvement: S does, A checks, the loop continues. The only
/// time a human uses /autonomic-listen is when something is wrong and we
/// have no other way to see what A sees (its prompt, its jobs, its recent
/// context). The human is a fallback, not a primary actor.
///
/// A is given the SAME context the autonomous hook would give it: soul
/// (from agent_souls), jobs (from agent_jobs), and (via the human's own
/// observation) the recent session log + commits that A normally sees. A
/// responds as if it were in autonomous mode — the human's message is just
/// the question, A's context is unchanged. This is the point: the debug tool
/// shows you what A actually sees, not an extended view.
///
/// A's response is:
///   1. saved to inter_reviews (same as the autonomous path)
///   2. sent to S via pi.sendMessage with triggerTurn: true (S sees it, can act)
///
/// A has NO tool-calling capability. It does not try to query the DB, run
/// terminal commands, or call psypi-* tools. If A needs data not in the
/// prompt, it writes that need into its review and S will fetch it in the
/// next turn. This is the explicit design (migration 038, 2026-06-02).
///
/// Self-monitor reminder: if the human is asking A about a tool error or a
/// strange environment symptom, A's job (from the self-monitor entry in
/// agent_jobs) is to report the anomaly to S via pi.sendMessage, not to
/// wait for the human to fix it. S investigates. The human should not need
/// to be in the loop.
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
      ctx_notify(ctx, "[AUTONOMIC] A loading soul + jobs...", "status")
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
                Ok(a_jobs) -> {
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
                  let user_prompt = build_user_prompt(args)
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
                          promise.resolve(Error("A failed to process: " <> e))
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
}

fn build_user_prompt(human_message: String) -> String {
  "## Mode: debug-only human message to A
" <> "The human is sending A a direct message (via /autonomic-listen). This is a debug tool, not a normal user-facing command. The human is peeking into A's environment because something looks wrong and there is no other way to see what A sees.\n" <> "A's context here is the same as the autonomous debounce path: soul + jobs + (when triggered) the recent session log and recent commits. The human's message is the question; A responds using the same context it would use autonomously.\n" <> "If the human is asking A about an environment anomaly (tool error, missing data, weird state), A's job is to self-monitor: report the anomaly to S via pi.sendMessage (triggerTurn: true) so S can investigate. The human is not the fix-it person. S is.\n\n" <> "## Human message\n" <> human_message <> "\n\n" <> "## A's expected response format\n" <> "Reply as plain text. Do NOT emit any tool-call XML (no <longcat_tool_call> or similar). A has no tool-calling capability.\n" <> "If the human is asking for an inter-review, structure the response as a normal inter-review: summary, score, findings, suggested next steps.\n" <> "If the human is asking A to act on something, A's role is to ask S to do it. A cannot do it directly. Compose a clear request for S in plain text.\n" <> "If A needs data that is not in its context, write the request as a finding (\"S, please run SELECT ...\") and S will fetch it.\n"
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
