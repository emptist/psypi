import gleam/list
import gleam/string

fn record_model_js(model_expr: String) -> String {
  [
    "    try {\n",
    "      if (" <> model_expr <> ") {\n",
    "        const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "        const result = await record_current_model(" <> model_expr <> ");\n",
    "        const r = unwrapGleamResult(result);\n",
    "        if (!r.ok) {\n",
    "          ctx.ui.notify('record_current_model failed: ' + r.error, 'error');\n",
    "        }\n",
    "      }\n",
    "    } catch(_err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn handler_body() -> String {
  [
    "    // session_start: record model (silent, non-blocking)\n",
    record_model_js("ctx.model"),
  ]
  |> string.concat
}
