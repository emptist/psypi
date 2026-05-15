// generator/before_agent_start.gleam — A-worker: evaluate context when idle
//
// When S is idle (ctx.isIdle() == true), A evaluates the session context
// and decides what to do next. A doesn't ask questions — A does work.

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: A-worker evaluates when S is idle\n",
    "    if (ctx.isIdle()) {\n",
    "      // S was idle. A evaluates context and injects a directive if needed.\n",
    "      // A decides what to do based on session context, tasks, issues, health.\n",
    "      // For now, just signal that A is aware.\n",
    "      ctx.ui.setStatus('psypi-autonomic', 'A-worker: S was idle, evaluating...');\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
