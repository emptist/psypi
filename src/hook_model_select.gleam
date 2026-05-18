import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // model_select: record model change (non-blocking)\n",
    "    try {\n",
    "      if (event.model) {\n",
    "        const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "        const result = await record_current_model(event.model);\n",
    "        const r = unwrapGleamResult(result);\n",
    "        if (!r.ok) {\n",
    "          ctx.ui.notify('model_select: record_current_model failed: ' + r.error, 'error');\n",
    "        }\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
