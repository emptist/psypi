import gleam/int
import gleam/list
import gleam/string

pub fn parse_context_window(usage_json: String) -> Result(Int, String) {
  let key = "\"contextWindow\":"
  case string.contains(usage_json, "contextWindow") {
    False -> Error("contextWindow not found in usage JSON")
    True -> {
      let parts = string.split(usage_json, key)
      case parts {
        [_, rest, ..] -> {
          let digits = rest |> string.trim_start |> extract_leading_digits
          case digits == "" {
            True ->
              Error(
                "contextWindow: no digits after "
                <> key
                <> " in "
                <> string.slice(usage_json, 0, 200),
              )
            False ->
              case int.parse(digits) {
                Ok(n) -> Ok(n)
                Error(_) ->
                  Error("contextWindow: failed to parse digits: " <> digits)
              }
          }
        }
        _ ->
          Error(
            "contextWindow: split on "
            <> key
            <> " failed. JSON: "
            <> string.slice(usage_json, 0, 200),
          )
      }
    }
  }
}

fn extract_leading_digits(s: String) -> String {
  s
  |> string.to_graphemes
  |> list.take_while(is_digit)
  |> string.concat
}

fn is_digit(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

pub fn current_time_ms() -> Int {
  let res = now_ms()
  case res {
    Ok(t) -> t
    Error(_) -> 0
  }
}

@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Result(Int, String)
