import gleam/dynamic/decode
import gleam/json
import gleam/string
import pi_extension.{pi_send_message}

/// Decoder for tool results that use { ok: bool, error?: string } shape
fn tool_error_decoder() -> decode.Decoder(String) {
  use ok <- decode.field("ok", decode.bool)
  case ok {
    True -> decode.failure("ok:true means no error", "expected ok:false")
    False -> {
      use error_msg <- decode.field("error", decode.string)
      decode.success(error_msg)
    }
  }
}

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
        "followUp",
      )
      Ok(Nil)
    }
  }
}

/// Try to parse the result JSON and detect if it represents an error.
/// Uses proper JSON decoding instead of fragile string matching.
/// Returns Ok(error_message) if an error is found, Error(Nil) otherwise.
fn try_parse_error(json_str: String) -> Result(String, Nil) {
  // Primary: decode as { ok: false, error: "message" }
  case json.parse(json_str, tool_error_decoder()) {
    Ok(error_msg) -> Ok(error_msg)
    Error(_) -> {
      // Fallback: check for execution/tool blocked markers via structured patterns
      // These are NOT normal tool output — they indicate tool execution was blocked
      let is_blocked =
        string.contains(json_str, "tool_execution_blocked")
        || string.contains(json_str, "execution error")

      case is_blocked {
        True -> Ok("Tool execution blocked or errored")
        False -> Error(Nil)
      }
    }
  }
}
