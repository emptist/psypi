// generator/before_agent_start.gleam — Empty (no A-worker trigger)

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: no A-worker trigger\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
