import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: no-op — Monitor uses direct messaging\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
