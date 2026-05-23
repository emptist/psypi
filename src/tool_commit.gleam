import gleam/int
import gleam/javascript/promise
import gleam/option.{None, Some}
import gleam/string
import inter_review
import pi_extension.{exec_sync}

/// Escape a string for safe use in a shell command.
/// Escapes backticks, dollar signs, double quotes, and backslashes.
fn shell_escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("`", "\\`")
  |> string.replace("$", "\\$")
}

pub fn on_commit(
  message: String,
  review_id: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  case review_id == "" {
    True -> trigger_review(message)
    False -> commit_if_reviewed(message, review_id)
  }
}

/// Phase 1: No review_id provided — create inter-review record in DB.
/// A-bot picks up the pending review autonomously via its agent_end hook.
/// Returns the review_id so S can call psypi-commit again (phase 2).
fn trigger_review(message: String) -> promise.Promise(Result(String, String)) {
  let diff = case exec_sync("git diff && git diff --cached") {
    Ok(out) ->
      case string.length(out) > 8000 {
        True -> string.slice(out, 0, 8000)
        False -> out
      }
    Error(_) -> ""
  }
  case diff == "" {
    True -> promise.resolve(Ok("No changes to commit."))
    False -> {
      let files = case exec_sync("git diff --name-only && git diff --cached --name-only") {
        Ok(out) -> out
        Error(_) -> ""
      }
      let context = "COMMIT: " <> message <> "\nFILES: " <> files <> "\nDIFF:\n" <> diff
      promise.map(inter_review.request_review(None, None, "autonomic", context), fn(result) {
        case result {
          Ok(rid) ->
            Ok("Inter-review triggered (ID: " <> rid <> "). A-bot will review autonomously. Call psypi-commit again with this review_id to commit.")
          Error(e) ->
            Error("Failed to trigger inter-review: " <> string.inspect(e))
        }
      })
    }
  }
}

/// Phase 2: review_id provided — validate it exists in DB and score >= 50.
/// If valid, proceed with git commit.
fn commit_if_reviewed(
  message: String,
  review_id: String,
) -> promise.Promise(Result(String, String)) {
  promise.map(inter_review.get_review_details(review_id), fn(result) {
    case result {
      Error(_) ->
        Error("Review not found: " <> review_id <> ". Run psypi-commit without review_id to trigger a review first.")
      Ok(review) -> {
        case review.overall_score {
          None ->
            Error("Review not yet complete. A-bot is still reviewing. Try again later.")
          Some(score) ->
            case score >= 50 {
              True -> {
                let escaped = shell_escape(message)
                let cmd = "git commit -m \"" <> escaped <> "\""
                case exec_sync(cmd) {
                  Ok(_) -> Ok("Committed: " <> message <> " (score: " <> int.to_string(score) <> "/100)")
                  Error(e) -> Error("git commit failed: " <> e)
                }
              }
              False ->
                Error("Review score too low: " <> int.to_string(score) <> "/100 (minimum 50). Fix issues and trigger a new review.")
            }
        }
      }
    }
  })
}
