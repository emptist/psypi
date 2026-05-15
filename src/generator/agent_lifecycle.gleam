// generator/agent_lifecycle.gleam — A-worker lifecycle hooks
//
// agent_end: S just finished working, A evaluates and prepares
// agent_start: S is starting, A stays silent

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
  [
    "    // agent_end: S just finished, A evaluates\n",
    "    // S is now idle. A checks context and decides what to do.\n",
    "    ctx.ui.setStatus('psypi-autonomic', 'A-worker: S finished, evaluating...');\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
