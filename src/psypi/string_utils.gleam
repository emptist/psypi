import gleam/string
import gleam/list

pub fn truncate(input: String, max_len: Int) -> String {
  case string.length(input) > max_len {
    True -> string.slice(input, 0, max_len) <> "..."
    False -> input
  }
}

pub fn split_lines(input: String) -> List(String) {
  string.split(input, "\n")
}

pub fn join_lines(lines: List(String), separator: String) -> String {
  string.join(lines, separator)
}

pub fn contains_any(input: String, patterns: List(String)) -> Bool {
  list.any(patterns, fn(pattern) {
    string.contains(input, pattern)
  })
}
