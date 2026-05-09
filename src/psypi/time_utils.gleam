import gleam/int
import gleam/javascript/promise

/// Get current time as ISO 8601 string using JavaScript Date
pub fn now_iso8601() -> promise.Promise(String) {
  promise.resolve("new Date().toISOString()")
}

/// Format seconds as minutes and seconds
pub fn format_duration(seconds: Int) -> String {
  let mins = seconds / 60
  let secs = seconds % 60
  case mins > 0 {
    True -> int.to_string(mins) <> "m " <> int.to_string(secs) <> "s"
    False -> int.to_string(secs) <> "s"
  }
}
