// generator/before_agent_start.gleam — Simple A-worker: ask S 2 questions when idle
//
// Design:
//   - Check ctx.isIdle() — only act when S is idle (not working)
//   - If idle, inject 2 questions into system prompt
//   - S answers naturally and continues working

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // before_agent_start: A-worker asks S 2 questions when idle\n",
    "    if (ctx.isIdle()) {\n",
    "      const questions = [\n",
    "        'What was the most important thing you just accomplished?',\n",
    "        'What should I make sure to remember for next time?',\n",
    "      ];\n",
    "      const qText = questions.map((q, i) => (i+1) + '. ' + q).join('\\n');\n",
    "      return {\n",
    "        systemPrompt: event.systemPrompt + '\\n\\n[Before you continue, I have 2 questions about your recent work:]\\n' + qText + '\\n\\n[Please answer them briefly, then continue with your work.]\\n'\n",
    "      };\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
