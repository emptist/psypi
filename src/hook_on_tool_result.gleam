import gleam/string
import pi_extension.{notify_error, pi_send_message}

pub fn on_tool_result(
  result_json: String,
  tool_name: String,
  pi: a,
) -> Result(Nil, String) {
  let is_error =
    string.contains(result_json, "\"error\"")
    || string.contains(result_json, "Error:")
    || string.contains(result_json, "execution error")
    || string.contains(result_json, "tool_execution_blocked")
    || string.contains(result_json, "\"is_error\":true")

  case is_error {
    False -> Ok(Nil)
    True -> {
      let error_msg = extract_error_msg(result_json)
      let display_name = case tool_name {
        "" -> "unknown"
        n -> n
      }
      let short_msg = case string.length(error_msg) > 200 {
        True -> string.slice(error_msg, 0, 200)
        False -> error_msg
      }
      notify_error(pi, "Tool error: " <> display_name <> " — " <> short_msg)
      pi_send_message(
        pi,
        "autonomic-error",
        "[from A-agentbot:] Tool error: " <> display_name <> " — " <> short_msg,
        "persistent",
      )
      Ok(Nil)
    }
  }
}

fn extract_error_msg(json: String) -> String {
  case string.split(json, "\"error\"") {
    [_, after] -> {
      case string.split(after, "\"") {
        [_, msg, ..] ->
          case string.slice(msg, 0, 200) {
            "" -> "Unknown error"
            m -> m
          }
        _ -> "Unknown error"
      }
    }
    _ -> {
      case string.split(json, "Error:") {
        [_, after] -> {
          let msg = string.trim(after)
          case string.slice(msg, 0, 200) {
            "" -> "Unknown error"
            m -> m
          }
        }
        _ -> "Unknown error"
      }
    }
  }
}
