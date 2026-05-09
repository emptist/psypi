import gleam/string
import gleam/list

/// Simple JSON string builder (without dependencies)
pub fn to_json_string(value: String) -> String {
  "\"" <> string.replace(value, "\"", "\\\"") <> "\""
}

pub fn list_to_json(
  items: List(String),
  formatter: fn(String) -> String,
) -> String {
  let formatted = items
    |> list.map(formatter)
    |> string.join(", ")
  "[" <> formatted <> "]"
}

pub fn key_value_to_json(
  pairs: List(#(String, String)),
) -> String {
  let formatted = pairs
    |> list.map(fn(pair) { "\"" <> pair.0 <> "\": \"" <> pair.1 <> "\"" })
    |> string.join(", ")
  "{" <> formatted <> "}"
}
