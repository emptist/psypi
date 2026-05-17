// generator/agent_end_coordination.gleam — Idle detection + wake-up on agent_end
//
// When agent_end fires, wait configurable milliseconds (default 15s), check
// ctx.isIdle(), and if still idle, let the A‑worker read the monitor brief
// and compose a wake‑up message.
//
// The debounce duration is read from system_config table (key: monitor_debounce_ms).
// The S‑worker can update this value at runtime to adjust timing.
// The brief (<200 words) contains hard‑to‑find knowledge. The A‑worker
// figures out the rest using its own intelligence.

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // A‑worker coordination: detect idle → read brief → compose → wake up S‑worker\n",
    "    ctx.ui.notify('[DEBUG] agent_end fired', 'info');\n",
    "    try {\n",
    "      // Read debounce from DB (default 15000ms)\n",
    "      let debounceMs = 15000;\n",
    "      try {\n",
    "        const { default: db } = await import('./build/dev/javascript/psypi/db_query.mjs');\n",
    "        const result = await db.query('SELECT value FROM system_config WHERE key = $1', ['monitor_debounce_ms']);\n",
    "        if (result.rows && result.rows[0] && result.rows[0][0]) {\n",
    "          const val = parseInt(result.rows[0][0]);\n",
    "          if (val && val > 0) { debounceMs = val; }\n",
    "        }\n",
    "      } catch(e) { /* use default */ }\n",
    "      ctx.ui.notify('[DEBUG] Starting debounce timer: ' + debounceMs + 'ms', 'info');\n",
    "      setTimeout(async () => {\n",
    "        try {\n",
    "          ctx.ui.notify('[DEBUG] Debounce fired, checking isIdle...', 'info');\n",
    "          if (ctx.isIdle()) {\n",
    "            ctx.ui.notify('[DEBUG] ctx.isIdle() = true, proceeding with A‑worker wake‑up', 'info');\n",
    "            let msg = '';\n",
    "            try {\n",
    "              ctx.ui.notify('[DEBUG] Reading MONITOR‑BRIEF.md...', 'info');\n",
    "              const fs = await import('fs');\n",
    "              const path = await import('path');\n",
    "              const briefPath = path.join(ctx.cwd, 'docs', 'MONITOR-BRIEF.md');\n",
    "              let brief = '';\n",
    "              try { brief = fs.readFileSync(briefPath, 'utf-8'); } catch(e) { ctx.ui.notify('[DEBUG] No MONITOR‑BRIEF.md found', 'info'); }\n",
    "              const usage = ctx.getContextUsage();\n",
    "              const tokenInfo = usage ? `Context: ${Math.round(usage.tokens / usage.contextWindow * 100)}% used.` : '';\n",
    "              const systemPrompt = `You are the Autonomic Worker (Monitor). The Somatic Worker has gone idle.\\n\\n${tokenInfo}\\n\\nMonitor Brief:\\n${brief}\\n\\nCompose a brief, natural wake‑up message (1‑2 sentences). Mention what needs attention. The S‑worker is smart — it will decide what to do. Prefix with [from A‑worker:].`;\n",
    "              ctx.ui.notify('[DEBUG] Calling callMonitor...', 'info');\n",
    "              const messages = [{ role: 'user', content: [{ type: 'text', text: 'Somatic worker is idle. Compose a wake‑up message.' }], timestamp: Date.now() }];\n",
    "              const composed = await callMonitor(ctx, messages, systemPrompt);\n",
    "              ctx.ui.notify('[DEBUG] callMonitor returned: ' + (composed ? composed.substring(0, 100) : 'null/empty'), 'info');\n",
    "              if (composed && composed.trim()) { msg = composed; }\n",
    "            } catch(e) {\n",
    "              ctx.ui.notify('[DEBUG] callMonitor failed: ' + e, 'error');\n",
    "              msg = `[from A‑worker:] callMonitor failed: ${e}`;\n",
    "            }\n",
    "            if (!msg || !msg.trim()) { msg = `[from A‑worker:] callMonitor returned empty`; }\n",
    "            ctx.ui.notify('[DEBUG] Sending wake‑up message to S‑worker...', 'info');\n",
    "            // Use sendMessage with triggerTurn to immediately wake up the S‑worker\n",
    "            pi.sendMessage({\n",
    "              customType: 'autonomic‑wakeup',\n",
    "              content: [{ type: 'text', text: msg }],\n",
    "              display: 'persistent',\n",
    "              details: { source: 'agent_end_coordination' }\n",
    "            }, { triggerTurn: true });\n",
    "            ctx.ui.notify('[DEBUG] Wake‑up message sent', 'info');\n",
    "          } else {\n",
    "            ctx.ui.notify('[DEBUG] ctx.isIdle() = false, skipping A‑worker wake‑up', 'info');\n",
    "          }\n",
    "        } catch(e) {\n",
    "          ctx.ui.notify('[DEBUG] Inner error: ' + e, 'error');\n",
    "        }\n",
    "      }, debounceMs);\n",
    "    } catch(err) {\n",
    "      ctx.ui.notify('[DEBUG] Outer error: ' + err, 'error');\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
