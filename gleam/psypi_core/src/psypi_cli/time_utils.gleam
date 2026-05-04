import gleam/string
import gleam/int
import gleam/javascript/promise

pub fn now_iso8601() -> promise.Promise(String) {
  // Use JavaScript Date to get ISO string
  let js_now = """
    new Date().toISOString()
  """
  // Simplified - returns placeholder
  promise.resolve("2026-05-04T15:48:00.000Z")
}

pub fn format_duration(seconds: Int) -> String {
  let mins = seconds / 60
  let secs = seconds % 60
  case mins > 0 {
    True -> int.to_string(mins) <> "m " <> int.to_string(secs) <> "s"
    False -> int.to_string(secs) <> "s"
  }
}
