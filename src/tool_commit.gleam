import gleam/javascript/promise
import gleam/string
import pi_extension.{exec_sync, notify_info, pi_send_message}

pub fn on_commit(
  message: String,
  review_id: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  case review_id == "" {
    True -> review_and_commit(message, ctx, pi)
    False -> commit_with_review_id(message, review_id)
  }
}

fn review_and_commit(message: String, ctx: a, pi: b) -> promise.Promise(Result(String, String)) {
  let changed_files = case exec_sync("git diff --name-only && git diff --cached --name-only") {
    Ok(out) -> out
    Error(_) -> ""
  }
  let diff = case exec_sync("git diff && git diff --cached") {
    Ok(out) ->
      case string.length(out) > 8000 {
        True -> string.slice(out, 0, 8000)
        False -> out
      }
    Error(_) -> ""
  }
  case changed_files == "" {
    True -> promise.resolve(Ok("No changes to review."))
    False -> {
      let review_request = "[from A-worker:] CODE REVIEW REQUEST\n\n"
        <> "CHANGES:\nFiles: " <> changed_files
        <> "\n---\nDIFF:\n" <> diff
        <> "\n---\nCOMMIT MESSAGE: " <> message
        <> "\n---\n"
        <> "Review the code above. Assess code quality, safety, and fit.\n"
        <> "Respond with: PASS or FAIL, SCORE/100, FEEDBACK.\n"
        <> "Format exactly: PASS SCORE:85 FEEDBACK:your feedback here"
      notify_info(ctx, "[AUTONOMIC] Sending code review request to S-worker")
      pi_send_message(pi, "autonomic-wakeup", review_request, "persistent")
      promise.resolve(Ok("Code review request sent to S-worker. The S-worker will review and respond."))
    }
  }
}

fn commit_with_review_id(
  message: String,
  review_id: String,
) -> promise.Promise(Result(String, String)) {
  let is_valid_uuid =
    string.length(review_id) == 36
    && string.contains(review_id, "-")
  case is_valid_uuid {
    False -> promise.resolve(Error("Invalid review_id format."))
    True -> {
      let escaped = string.replace(message, "\"", "\\\"")
      let cmd = "git add -A && git commit -m \"" <> escaped <> "\""
      case exec_sync(cmd) {
        Ok(_) -> promise.resolve(Ok("Committed: " <> message))
        Error(e) -> promise.resolve(Error("Commit failed: " <> e))
      }
    }
  }
}
