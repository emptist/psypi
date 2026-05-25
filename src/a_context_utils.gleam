import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

pub fn parse_context_window(usage_json: String) -> Result(Int, String) {
  usage_json
  |> json.parse(using: context_window_decoder())
  |> map_decode_error
}

fn context_window_decoder() -> decode.Decoder(Int) {
  use context_window <- decode.field("contextWindow", decode.int)
  decode.success(context_window)
}

fn map_decode_error(r: Result(Int, json.DecodeError)) -> Result(Int, String) {
  case r {
    Ok(n) -> Ok(n)
    Error(e) ->
      Error("contextWindow: JSON decode failed: " <> json_decode_error_to_string(e))
  }
}

fn json_decode_error_to_string(e: json.DecodeError) -> String {
  case e {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(s) -> "unexpected byte: " <> s
    json.UnexpectedSequence(s) -> "unexpected sequence: " <> s
    json.UnableToDecode(errors) ->
      errors
      |> list.map(fn(err: decode.DecodeError) {
        err.path |> string.join(".")
        <> ": expected "
        <> err.expected
        <> ", found "
        <> err.found
      })
      |> string.join(", ")
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
