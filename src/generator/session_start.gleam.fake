// generator/session_start.gleam — Session initialization (silent)

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // Session start: record model (silent)\n",
    "    try {\n",
    "      const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "      if (ctx.model) {\n",
    "        record_current_model(ctx.model).then(() => {}).catch(() => {});\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
