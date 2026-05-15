// generator/session_start.gleam — Session initialization
// Checks system health and displays [Autonomic] message if issues found

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // Session start: check health, display [Autonomic] message if issues\n",
    "    try {\n",
    "      const { record_current_model } = await import('./build/dev/javascript/psypi/monitor.mjs');\n",
    "      if (ctx.model) {\n",
    "        record_current_model(ctx.model).then(() => {}).catch(() => {});\n",
    "      }\n",
    "      const { check_system_health } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');\n",
    "      const health = await check_system_health();\n",
    "      if (health.ok) {\n",
    "        const failed = health.value.failed_tasks;\n",
    "        const issues = health.value.open_issues;\n",
    "        if (failed > 0 || issues > 0) {\n",
    "          const msg = '[Autonomic] System check: ' + failed + ' failed tasks, ' + issues + ' open issues. Directing Somatic Worker to investigate.';\n",
    "          ctx.ui.notify(msg, 'warning');\n",
    "        } else {\n",
    "          ctx.ui.setStatus('psypi-autonomic', '[Autonomic] System healthy');\n",
    "        }\n",
    "      }\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
