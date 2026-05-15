// generator/before_agent_start.gleam — Empty (no A-worker trigger here)
// A-worker is only activated for inter-review and commit via psypi-commit tool

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: no A-worker trigger (only for inter-review/commit)\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
