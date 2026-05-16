// generator/agent_end_coordination.gleam — Idle detection + wake-up on agent_end
//
// When agent_end fires, wait 5 seconds, check ctx.isIdle(), and if still idle,
// let the A-worker compose a brief wake-up message via LLM.
// No hardcoded instructions — the A-worker thinks for itself.

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // A-worker coordination: detect idle → compose message → wake up S-worker\n",
    "    try {\n",
    "      setTimeout(async () => {\n",
    "        try {\n",
    "          if (ctx.isIdle()) {\n",
    "            let msg = '[Monitor] Wake up.';\n",
    "            try {\n",
    "              const usage = ctx.getContextUsage();\n",
    "              const tokenInfo = usage ? `Context: ${Math.round(usage.tokens / usage.contextWindow * 100)}% used.` : '';\n",
    "              const systemPrompt = `You are the Autonomic Worker (Monitor). The Somatic Worker has gone idle. ${tokenInfo} Compose a brief, natural wake-up message (1 sentence). Let the worker decide what to do next. Prefix with [Monitor].`;\n",
    "              const messages = [{ role: 'user', content: [{ type: 'text', text: 'The worker is idle. Compose a wake-up message.' }], timestamp: Date.now() }];\n",
    "              const composed = await callMonitor(ctx, messages, systemPrompt);\n",
    "              if (composed && composed.trim()) { msg = composed; }\n",
    "            } catch(e) {\n",
    "              // LLM compose failed — use fallback\n",
    "            }\n",
    "            // [M] Method 1: pi.sendMessage — direct message to current session\n",
    "            pi.sendMessage({\n",
    "              customType: 'monitor-calling',\n",
    "              content: [{ type: 'text', text: msg }],\n",
    "              display: 'persistent',\n",
    "              details: { source: 'agent_end_coordination' }\n",
    "            }, { triggerTurn: true });\n",
    "            // [B] Method 2: pi.broadcast — global broadcast (uncomment to test)\n",
    "            // pi.broadcast(msg);\n",
    "          }\n",
    "        } catch(e) {\n",
    "          // Non-blocking\n",
    "        }\n",
    "      }, 5000);\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
