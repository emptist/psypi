import gleam/string
import gleam/list

/// Capitalize first letter of each word
pub fn title_case(input: String) -> String {
  input
  |> string.split(" ")
  |> list.map(fn(word) {
    case string.length(word) {
      0 -> ""
      _ -> {
        let first = string.slice(word, 0, 1)
        let rest = string.slice(word, 1, string.length(word))
        string.uppercase(first) <> string.lowercase(rest)
      }
    }
  })
  |> string.join(" ")
}

/// Truncate string with ellipsis
pub fn truncate(input: String, max_len: Int) -> String {
  case string.length(input) > max_len {
    True -> string.slice(input, 0, max_len - 3) <> "..."
    False -> input
  }
}

/// Count occurrences of pattern in string
pub fn count_occurrences(input: String, pattern: String) -> Int {
  let parts = string.split(input, pattern)
  list.length(parts) - 1
}
