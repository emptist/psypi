import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // session_start: record model (silent, non-blocking)\n",
    "    try {\n",
    "      if (ctx.model) {\n",
    "        const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "        const result = await record_current_model(ctx.model);\n",
    "        const r = unwrapGleamResult(result);\n",
    "        if (!r.ok) {\n",
    "          ctx.ui.notify('session_start: record_current_model failed: ' + r.error, 'error');\n",
    "        }\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
