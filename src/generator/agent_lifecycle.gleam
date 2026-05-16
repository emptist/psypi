// generator/agent_lifecycle.gleam — A‑worker lifecycle hooks
//
// agent_end: S just finished working, A checks idle and sends wake-up
// agent_start: S is starting, A stays silent

import generator/agent_end_coordination
import gleam/list
import gleam/string

pub fn start_body() -> String {
  [
    "    // agent_start: S is starting, A stays silent\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn end_body() -> String {
  agent_end_coordination.handler_body()
}
