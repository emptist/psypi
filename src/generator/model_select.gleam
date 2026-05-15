import gleam/list
// generator/model_select.gleam — Record model changes

import gleam/string

pub fn handler_body() -> String {
  [
    "    try {\n",
    "      const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "      if (event.model) {\n",
    "        record_current_model(event.model).then(() => {}).catch(() => {});\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
