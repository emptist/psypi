import gleam/list
import gleam/string
import hook_agent_end_coordination

pub fn start_body() -> String {
  [
    "    // agent_start: S is starting, A stays silent\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn end_body() -> String {
  hook_agent_end_coordination.handler_body()
}
