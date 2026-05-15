import gleam/list
// generator/tool_result.gleam — Detect errors, create directives for Autonomic Worker

import gleam/string

pub fn handler_body() -> String {
  [
    "    // Detect errors → create directive for Autonomic Worker to investigate\n",
    "    try {\n",
    "      const resultStr = JSON.stringify(event.result || '');\n",
    "      const isError = resultStr.includes('\"error\"') || resultStr.includes('Error:') || resultStr.includes('execution error') || resultStr.includes('tool_execution_blocked') || resultStr.includes('\"is_error\":true');\n",
    "      if (!isError) return;\n",
    "\n",
    "      let errorMsg = 'Unknown error';\n",
    "      try {\n",
    "        const resultObj = JSON.parse(resultStr);\n",
    "        errorMsg = resultObj.error || resultObj.message || resultObj.content?.[0]?.text || errorMsg;\n",
    "      } catch(e) {}\n",
    "\n",
    "      // Create directive for Autonomic Worker\n",
    "      const { set_directive } = await import('./build/dev/javascript/psypi/directive.mjs');\n",
    "      const directive = 'INVESTIGATE: Tool \"' + (event.toolName || 'unknown') + '\" failed: ' + errorMsg.substring(0, 300) + '. Analyze root cause and fix.';\n",
    "      set_directive(directive, 'high').then(() => {}).catch(() => {});\n",
    "\n",
    "      // Also auto-file as issue for tracking\n",
    "      const { auto_file_issue } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');\n",
    "      auto_file_issue(event.toolName || 'unknown', errorMsg).then(() => {}).catch(() => {});\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
