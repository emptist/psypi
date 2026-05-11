// Simple text operations module
import gleam/string
import gleam/list

/// Capitalize first letter of string
pub fn capitalize(input: String) -> String {
  case string.is_empty(input) {
    True -> ""
    False -> {
      let first = string.slice(input, 0, 1)
      let rest = string.slice(input, 1, string.length(input))
      string.uppercase(first) <> string.lowercase(rest)
    }
  }
}

/// Check if string is numeric
pub fn is_numeric(input: String) -> Bool {
  case string.is_empty(input) {
    True -> False
    False -> {
      let chars = string.to_graphemes(input)
      list.all(chars, fn(c) { 
        string.contains("0123456789", c)
      })
    }
  }
}

/// Simple pluralize (add 's' if not ending in 's')
pub fn pluralize(word: String) -> String {
  case string.ends_with(word, "s") {
    True -> word <> "es"
    False -> word <> "s"
  }
}
