// generator/tool_result.gleam — Detect errors, notify + inject into session

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // Detect errors → notify (debug) + inject into session for S-worker\n",
    "    try {\n",
    "      const resultStr = JSON.stringify(event.result || '');\n",
    "      const isError = resultStr.includes('\"error\"') || resultStr.includes('Error:') || resultStr.includes('execution error') || resultStr.includes('tool_execution_blocked') || resultStr.includes('\"is_error\":true');\n",
    "      if (!isError) return;\n",
    "      let errorMsg = 'Unknown error';\n",
    "      try {\n",
    "        const resultObj = JSON.parse(resultStr);\n",
    "        errorMsg = resultObj.error || resultObj.message || resultObj.content?.[0]?.text || errorMsg;\n",
    "      } catch(e) {}\n",
    "      // Debug: log error in UI\n",
    "      ctx.ui.notify('Tool error: ' + (event.toolName || 'unknown') + ' — ' + errorMsg.substring(0, 200), 'error');\n",
    "      // Inject into session and force immediate new turn\n",
    "      pi.sendMessage({\n",
    "        customType: 'autonomic-error',\n",
    "        content: [{ type: 'text', text: '[from A-worker:] Tool error: ' + (event.toolName || 'unknown') + ' — ' + errorMsg.substring(0, 200) }],\n",
    "        display: 'persistent',\n",
    "        details: { source: 'tool_result', toolName: event.toolName }\n",
    "      }, { triggerTurn: true });\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
