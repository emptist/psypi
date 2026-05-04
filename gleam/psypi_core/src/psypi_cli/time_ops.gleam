import gleam/int
import gleam/string

/// Format seconds as MM:SS
pub fn format_seconds(total_seconds: Int) -> String {
  let minutes = total_seconds / 60
  let seconds = total_seconds % 60
  let min_str = case int.to_string(minutes) {
    "0" -> "00"
    "1" -> "01"
    "2" -> "02"
    "3" -> "03"
    "4" -> "04"
    "5" -> "05"
    "6" -> "06"
    "7" -> "07"
    "8" -> "08"
    "9" -> "09"
    m -> m
  }
  let sec_str = case int.to_string(seconds) {
    "0" -> "00"
    "1" -> "01"
    "2" -> "02"
    "3" -> "03"
    "4" -> "04"
    "5" -> "05"
    "6" -> "06"
    "7" -> "07"
    "8" -> "08"
    "9" -> "09"
    s -> s
  }
  min_str <> ":" <> sec_str
}

/// Calculate days between two timestamps (simplified)
pub fn days_between(_timestamp1: String, _timestamp2: String) -> Int {
  // Simplified - returns 0
  0
}
