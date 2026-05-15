// generator/before_agent_start.gleam — Simple A-worker: ask S 2 questions when idle
//
// Design:
//   - Check ctx.isIdle() — only act when S is idle (not working)
//   - If idle, inject a prompt that tells A to ask 2 questions
//   - A decides what to ask based on context
//   - S answers naturally and continues working

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: A-worker asks S 2 questions when idle\n",
    "    if (ctx.isIdle()) {\n",
    "      return {\n",
    "        systemPrompt: event.systemPrompt + '\\n\\n[Autonomic Worker]: You were idle. Before continuing, ask the Somatic Worker 2 questions to understand their recent work and get them back on track. Base your questions on the session context — what they were doing, what they accomplished, what they need. Keep the questions concise and actionable.\\n'\n",
    "      };\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
