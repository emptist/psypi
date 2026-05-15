// generator/tool_result.gleam — Detect errors, log only (no A-worker trigger)

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // Detect errors → log only, no A-worker trigger\n",
    "    try {\n",
    "      const resultStr = JSON.stringify(event.result || '');\n",
    "      const isError = resultStr.includes('\"error\"') || resultStr.includes('Error:') || resultStr.includes('execution error') || resultStr.includes('tool_execution_blocked') || resultStr.includes('\"is_error\":true');\n",
    "      if (!isError) return;\n",
    "      let errorMsg = 'Unknown error';\n",
    "      try {\n",
    "        const resultObj = JSON.parse(resultStr);\n",
    "        errorMsg = resultObj.error || resultObj.message || resultObj.content?.[0]?.text || errorMsg;\n",
    "      } catch(e) {}\n",
    "      // Log error only — no directive creation, no A-worker trigger\n",
    "      ctx.ui.notify('Tool error: ' + (event.toolName || 'unknown') + ' — ' + errorMsg.substring(0, 200), 'error');\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
