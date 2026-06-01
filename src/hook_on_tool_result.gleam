import gleam/string
import pi_extension.{pi_send_message}

pub fn on_tool_result(
  result_json: String,
  tool_name: String,
  pi: a,
) -> Result(Nil, String) {
  case try_parse_error(result_json) {
    Error(_) -> Ok(Nil)
    Ok(error_msg) -> {
      let display_name = case tool_name {
        "" -> "unknown"
        n -> n
      }
      let short_msg = case string.length(error_msg) > 200 {
        True -> string.slice(error_msg, 0, 200)
        False -> error_msg
      }
      pi_send_message(
        pi,
        "autonomic-error",
        "[from A-agentbot:] Tool error: " <> display_name <> " — " <> short_msg,
        "persistent",
        False,
      )
      Ok(Nil)
    }
  }
}

/// Try to parse the result JSON and detect if it represents an error.
/// Returns Ok(error_message) if an error is found, Error(Nil) otherwise.
fn try_parse_error(json: String) -> Result(String, Nil) {
  // Look for the top-level ok:false pattern first
  case string.contains(json, "\"ok\":false") {
    True -> {
      let msg = extract_json_field(json, "error")
      Ok(msg)
    }
    False -> {
      // Fallback: check for other error indicators
      let has_error_marker =
        string.contains(json, "Error:")
        || string.contains(json, "execution error")
        || string.contains(json, "tool_execution_blocked")

      case has_error_marker {
        True -> {
          let msg = case string.split(json, "Error:") {
            [_, after] -> {
              let trimmed = string.trim(after)
              case string.length(trimmed) {
                0 -> "Unknown error"
                _ -> string.slice(trimmed, 0, 200)
              }
            }
            _ -> "Unknown error"
          }
          Ok(msg)
        }
        False -> Error(Nil)
      }
    }
  }
}

/// Extract a field value from a simple JSON string.
/// Handles both string values ("error": "msg") and object values ("error": {...}).
fn extract_json_field(json: String, field: String) -> String {
  let field_pattern = "\"" <> field <> "\""
  case string.split(json, field_pattern) {
    [_, after] -> {
      let trimmed = string.trim(after)
      case string.length(trimmed) {
        0 -> "Unknown error"
        _ -> {
          let first = string.slice(trimmed, 0, 1)
          case first {
            // String value: "error": "some message"
            "\"" -> {
              let without_quote = case string.split(trimmed, "\"") {
                [_quote, value, ..] -> value
                _ -> trimmed
              }
              without_quote
            }
            // Object value: "error": {...}
            "{" -> string.slice(trimmed, 0, 200)
            _ -> string.slice(trimmed, 0, 200)
          }
        }
      }
    }
    _ -> "Unknown error"
  }
}
