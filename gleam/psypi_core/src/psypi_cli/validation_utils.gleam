import gleam/string
import gleam/list

pub type ValidationError {
  TooShort(Int)
  TooLong(Int)
  InvalidFormat(String)
}

/// Validate string length
pub fn validate_length(
  input: String,
  min: Int,
  max: Int,
) -> Result(String, ValidationError) {
  let len = string.length(input)
  case len < min, len > max {
    True, _ -> Error(TooShort(min))
    _, True -> Error(TooLong(max))
    _, _ -> Ok(input)
  }
}

/// Validate content has no dangerous patterns
pub fn validate_safe_content(input: String) -> Result(String, ValidationError) {
  let dangerous = ["rm -rf", "DROP TABLE", "DELETE FROM"]
  let has_dangerous = list.any(dangerous, fn(pattern) {
    string.contains(input, pattern)
  })
  case has_dangerous {
    True -> Error(InvalidFormat("Contains dangerous pattern"))
    False -> Ok(input)
  }
}
