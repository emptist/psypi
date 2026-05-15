// generator/agent_lifecycle.gleam — Agent lifecycle hooks (silent)

import gleam/list
import gleam/string

pub fn start_body() -> String {
  [
    "    // Autonomic: Track agent activity (silent)\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn end_body() -> String {
  [
    "    // Autonomic: Track session completion (silent)\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
