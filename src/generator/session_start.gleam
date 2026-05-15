// generator/session_start.gleam — Session initialization (silent)

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // Session start: record model, set status (silent)\n",
    "    try {\n",
    "      const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "      if (ctx.model) {\n",
    "        record_current_model(ctx.model).then(() => {}).catch(() => {});\n",
    "      }\n",
    "      const { check_system_health } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');\n",
    "      const health = await check_system_health();\n",
    "      const status = health.ok && health.value.failed_tasks === 0 ? 'psypi-autonomic: healthy' : 'psypi-autonomic: attention needed';\n",
    "      ctx.ui.setStatus('psypi-autonomic', status);\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
