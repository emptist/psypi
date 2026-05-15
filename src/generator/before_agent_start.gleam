// generator/before_agent_start.gleam — Simple restart question for S-worker

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // AUTONOMIC: Ask S-worker what's next (simple restart)\n",
    "    try {\n",
    "      return {\n",
    "        systemPrompt: event.systemPrompt + '\\n\\n[DIRECTIVES]\\n1. [Autonomic] What is the next step you plan to do to improve psypi?\\n[END DIRECTIVES]',\n",
    "      };\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
