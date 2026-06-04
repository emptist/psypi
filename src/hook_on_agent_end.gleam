import a_context_utils
import a_db_reader
import a_prompt_builder
import gleam/int
import gleam/javascript/promise
import gleam/string
import inter_review
import pi_extension.{
  call_monitor, ctx_get_context_usage_json, ctx_get_cwd,
  ctx_get_entries_json, ctx_is_idle, ctx_notify, now_ms, pi_send_message,
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
      // ✅ CORRECT: Error reporting via pi.sendMessage, not ctx.ui.notify.
      //   customType = "autonomic-error"      → dedicated error channel
      //   triggerTurn = False                 → do NOT wake S on a single error
      //   deliverAs  = "followUp"             → S will see this in its next
      //                                          turn (when something else
      //                                          legitimately wakes S)
      // S will only react if/when one of the legitimate wake-S conditions
      // is met (A's review was saved, A is stuck on save failure, etc).
      // Waking S on every error is exactly the "panic on any error"
      // behaviour the user has explicitly banned.
      let msg =
        "[A-agentbot] <ERROR> parse_context_window: "
        <> e
        <> ". Raw JSON: "
        <> string.slice(usage_json, 0, 300)
      pi_send_message(pi, "autonomic-error", msg, "persistent", False, "followUp")
      promise.resolve(Ok(Nil))
    }
    Ok(context_window) -> {
      let _ = ctx_notify(ctx, "[A-agentbot] Reading soul from database...", "status")
      promise.await(a_db_reader.read_soul_from_db(), fn(soul_result) {
        case soul_result {
          // ✅ CORRECT: Error reporting via pi_send_message. See the
          // first error_catch above for the full rationale on the
          // (customType, triggerTurn, deliverAs) tuple.
          Error(e) -> {
            let msg =
              "[A-agentbot] <ERROR> read_soul_from_db: "
              <> e
            pi_send_message(pi, "autonomic-error", msg, "persistent", False, "followUp")
            promise.resolve(Ok(Nil))
          }
          Ok(soul_content) -> {
            let _ = ctx_notify(ctx, "[A-agentbot] Reading A jobs from database...", "status")
            promise.await(a_db_reader.read_a_jobs_from_db(), fn(jobs_result) {
              case jobs_result {
                // ✅ CORRECT: Error reporting via pi_send_message. Same
                // (customType="autonomic-error", triggerTurn=False,
                // deliverAs="followUp") contract. A reading the jobs
                // table is a precondition for A to do any work; if it
                // fails, the conversation log must know, but S must not
                // be woken just to be told "A can't see its own jobs".
                Error(e) -> {
                  let msg =
                    "[A-agentbot] <ERROR> read_a_jobs_from_db: "
                    <> e
                  pi_send_message(pi, "autonomic-error", msg, "persistent", False, "followUp")
                  promise.resolve(Ok(Nil))
                }
                Ok(a_jobs) -> {
                  let _ = ctx_notify(ctx, "[A-agentbot] Getting last session time...", "status")
                  promise.await(
                    a_db_reader.get_last_a_session_at(),
                    fn(last_session_result) {
                      let last_session = case last_session_result {
                        Ok(ts) -> ts
                        Error(_) -> ""
                      }
                      let _ = ctx_notify(ctx, "[A-agentbot] Getting recent commits...", "status")
                      let commit_info = get_recent_commits(last_session)
                      let _ = ctx_notify(ctx, "[A-agentbot] Building system prompt...", "status")
                      let system_prompt =
                        system_prompt_types.compose(a_prompt_builder.build_system_prompt(
                          soul_content,
                          a_jobs,
                          context_window,
                        ))
                      let _ = ctx_notify(ctx, "[A-agentbot] Building user prompt...", "status")
                      let user_prompt =
                        a_prompt_builder.build_user_prompt(
                          usage_json,
                          entries_json,
                          cwd,
                          "",
                          commit_info,
                        )
                      let _ = ctx_notify(ctx, "[A-agentbot] Calling monitor...", "status")
                      promise.await(
                        call_monitor(ctx, user_prompt, system_prompt),
                        fn(monitor_result) {
                          case monitor_result {
                            Ok(response) -> {
                              let #(response, ids_stripped) = strip_hallucinated_ids(response)
                              case ids_stripped {
                                True ->
                                  ctx_notify(
                                    ctx,
                                    "[A-agentbot] Stripped hallucinated ID string(s) from response before save",
                                    "info",
                                  )
                                False -> Nil
                              }
                              case ctx_is_idle(ctx) {
                                True -> {
                                  let _ = ctx_notify(ctx, "[A-agentbot] Updating session time...", "status")
                                  let _ = psypi_config.set(
                                    "last_a_session_at",
                                    int.to_string(now_ms()),
                                  )
                                  let _ = ctx_notify(ctx, "[A-agentbot] Saving inter-review to database...", "status")
                                  let score = a_prompt_builder.parse_review_score(response)
                                  promise.await(
                                    inter_review.save(
                                      "A-agentbot",
                                      response,
                                      score,
                                      "[]",
                                      "[]",
                                    ),
                                    fn(save_result) {
                                      case save_result {
                                        Ok(review_id) -> {
                                          let tagged = case string.starts_with(response, "[A]") || string.starts_with(response, "[A-agentbot]") {
                                            True -> response
                                            False -> "[A-agentbot] " <> response
                                          }
                                          let msg_with_id = tagged <> "\n\n[inter-review id: " <> review_id <> "]"
                                          // ✅ CORRECT: This is a legitimate
                                          // "wake S after A finished its
                                          // work" call (A's review is saved
                                          // with an ID, A is done, S should
                                          // pick it up and act). Per the
                                          // Error reporting system rule:
                                          //   customType  = "autonomic-wakeup"
                                          //   triggerTurn = True  ← only allowed
                                          //                              when A has
                                          //                              finished
                                          //                              work or is
                                          //                              stuck
                                          //   deliverAs   = "followUp"
                                          // DO NOT copy this triggerTurn=True
                                          // pattern into an Error path — that
                                          // is the "panic on any error"
                                          // behaviour the user has banned.
                                          pi_send_message(
                                            pi,
                                            "autonomic-wakeup",
                                            msg_with_id,
                                            "persistent",
                                            True,
                                            "followUp",
                                          )
                                        }
                                        Error(save_err) -> {
                                          // ⚠️ Mixed case: the local toast
                                          // below uses ctx_notify with the
                                          // string "<ERROR> ...", which
                                          // violates the Error reporting
                                          // rule (ctx.ui.notify is not an
                                          // Error path). It is acceptable
                                          // here ONLY because the
                                          // conversation log message that
                                          // follows (msg_for_s) carries
                                          // the real Error to S via
                                          // pi_send_message — the local
                                          // toast is just a heads-up for
                                          // the human. Migration target:
                                          // drop the ctx_notify and rely
                                          // on the wake-up message alone.
                                          let save_err_str = inter_review_error_to_string(save_err)
                                          let _ = ctx_notify(
                                            ctx,
                                            "[A-agentbot] <ERROR> inter-review save failed: " <> save_err_str,
                                            "error",
                                          )
                                          let tagged = case string.starts_with(response, "[A]") || string.starts_with(response, "[A-agentbot]") {
                                            True -> response
                                            False -> "[A-agentbot] " <> response
                                          }
                                          let msg_for_s = "[SAVE FAILED] A's inter-review could not be persisted to the database ("
                                            <> save_err_str
                                            <> "). S, please consider saving this manually via psypi-inter-reviews.\n\n"
                                            <> tagged
                                          // ✅ CORRECT: This is the second
                                          // legitimate triggerTurn=True
                                          // case — A's work is BLOCKED
                                          // (could not persist the
                                          // review) and A is stuck. The
                                          // user has explicitly approved
                                          // waking S in this scenario so
                                          // S can decide whether to save
                                          // the review manually. Same
                                          // (customType, deliverAs) tuple
                                          // as the success branch above.
                                          pi_send_message(
                                            pi,
                                            "autonomic-wakeup",
                                            msg_for_s,
                                            "persistent",
                                            True,
                                            "followUp",
                                          )
                                        }
                                      }
                                      promise.resolve(Ok(Nil))
                                    },
                                  )
                                }
                                False -> {
                                  let _ = ctx_notify(ctx, "[A-agentbot] Cancelled due to user activity", "status")
                                  promise.resolve(Ok(Nil))
                                }
                              }
                            }
                            Error(e) -> {
                              // ✅ CORRECT: Error reporting via pi_send_message.
                              // Same (customType="autonomic-error",
                              // triggerTurn=False, deliverAs="followUp")
                              // contract as the other error sites in this
                              // file. The local ctx_notify below is a
                              // status toast for the human, NOT the
                              // Error reporting channel — the real Error
                              // goes through pi_send_message.
                              let _ = ctx_notify(ctx, "[A-agentbot] Monitor error occurred", "status")
                              pi_send_message(
                                pi,
                                "autonomic-error",
                                "[A-agentbot] <ERROR> call_monitor: " <> e,
                                "persistent",
                                False,
                                "followUp",
                              )
                              promise.resolve(Ok(Nil))
                            }
                          }
                        },
                      )
                    },
                  )
                }
              }
            })
          }
        }
      })
    }
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
    Ok(out) -> out
    Error(_) -> ""
  }
}

fn inter_review_error_to_string(e: inter_review.InterReviewError) -> String {
  case e {
    inter_review.ConnectionError(msg) -> "DB connection: " <> msg
    inter_review.QueryError(msg) -> "DB query: " <> msg
    inter_review.DecodeError(msg) -> "DB decode: " <> msg
  }
}

/// Strip hallucinated ID patterns from A's response.
///
/// A may imitate the `[inter-review id: <uuid>]` or `[review id: <uuid>]`
/// pattern that it saw in the preloaded session log (where a prior
/// review's hook-appended ID lives). The hook owns ID assignment, so
/// any such pattern in A's response is stripped before save. The
/// canonical ID is appended by the hook after the cleaned response is
/// saved.
///
/// Returns the cleaned response and a boolean indicating whether any
/// pattern was stripped. If a pattern is found but has no closing
/// `]` (malformed), the original string is returned untouched.
fn strip_hallucinated_ids(response: String) -> #(String, Bool) {
  let patterns = ["[inter-review id:", "[review id:"]
  strip_hallucinated_ids_loop(response, patterns, False)
}

fn strip_hallucinated_ids_loop(
  s: String,
  patterns: List(String),
  stripped: Bool,
) -> #(String, Bool) {
  case patterns {
    [] -> #(s, stripped)
    [pat, ..rest] -> {
      case string.split_once(s, pat) {
        Error(_) -> strip_hallucinated_ids_loop(s, rest, stripped)
        Ok(parts) -> {
          // Found the pattern. Look for the closing `]` after it.
          case string.split_once(parts.1, "]") {
            Error(_) ->
              // Malformed (no closing `]`). Leave the response alone
              // for this pattern; try the next one.
              strip_hallucinated_ids_loop(s, rest, stripped)
            Ok(rest_parts) -> {
              let cleaned = parts.0 <> rest_parts.1
              // Re-scan from the start of the pattern list on the
              // cleaned string in case multiple occurrences exist.
              strip_hallucinated_ids_loop(cleaned, patterns, True)
            }
          }
        }
      }
    }
  }
}
