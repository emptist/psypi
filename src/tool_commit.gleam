import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/string
import pi_extension.{call_monitor, exec_sync}

pub fn on_commit(
  message: String,
  review_id: String,
  ctx: a,
) -> promise.Promise(Result(String, String)) {
  case review_id == "" {
    True -> review_and_commit(message, ctx)
    False -> commit_with_review_id(message, review_id)
  }
}

fn review_and_commit(message: String, ctx: a) -> promise.Promise(Result(String, String)) {
  let changed_files = case exec_sync("git diff --name-only") {
    Ok(out) -> out
    Error(_) -> ""
  }
  let diff = case exec_sync("git diff") {
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
      let context_text = "CHANGES:\nFiles: "
        <> changed_files
        <> "\n---\nDIFF:\n"
        <> diff
        <> "\n---\nCOMMIT MESSAGE: "
        <> message
        <> "\n---\nREVIEW: Assess code quality, safety, and fit. Respond: PASS or FAIL, SCORE/100, FEEDBACK."
      let system_prompt = "You are Monitor. Review code. Be thorough but fair."
      promise.map(
        call_monitor(ctx, context_text, system_prompt),
        fn(result) {
          case result {
            Ok(response) -> {
              let is_pass = string.contains(response, "PASS")
              let score = extract_score(response)
              case is_pass && score >= 70 {
                False ->
                  Ok("Review: "
                    <> response
                    <> "\n\nScore "
                    <> int.to_string(score)
                    <> "/100 - Need improvements. Fix and run psypi-commit again.")
                True -> {
                  let new_review_id = generate_uuid()
                  Ok("Review PASSED ("
                    <> int.to_string(score)
                    <> "/100)\nreview_id: "
                    <> new_review_id
                    <> "\n\nTo commit: psypi-commit --review-id="
                    <> new_review_id
                    <> " \""
                    <> message
                    <> "\"")
                }
              }
            }
            Error(e) -> Error("Review failed: " <> e)
          }
        },
      )
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

fn extract_score(response: String) -> Int {
  let parts = string.split(response, "SCORE")
  case list.rest(parts) {
    Error(_) -> 0
    Ok(tail) -> {
      case list.first(tail) {
        Error(_) -> 0
        Ok(rest) -> {
          let digits = rest
            |> string.slice(0, 10)
            |> extract_digits
          case digits == "" {
            True -> 0
            False -> {
              case int.parse(digits) {
                Ok(n) -> n
                Error(_) -> 0
              }
            }
          }
        }
      }
    }
  }
}

fn extract_digits(s: String) -> String {
  s
  |> string.to_graphemes
  |> list.take_while(fn(c) {
    c == "0" || c == "1" || c == "2" || c == "3" || c == "4"
      || c == "5" || c == "6" || c == "7" || c == "8" || c == "9"
  })
  |> string.concat
}

fn generate_uuid() -> String {
  "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  |> string.to_graphemes
  |> list.map(fn(c) {
    case c == "x" || c == "y" {
      False -> c
      True -> {
        let r = int.random(16)
        case c == "y" {
          True -> int.to_string(int.bitwise_and(r, 3) + 8)
          False -> int.to_string(r)
        }
      }
    }
  })
  |> string.concat
}
