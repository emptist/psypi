// generator/agent_end_coordination.gleam — Idle detection + wake-up on agent_end
//
// When agent_end fires, wait 5 seconds, check ctx.isIdle(), and if still idle,
// let the A-worker compose a contextual wake-up message via LLM.
//
// Two send methods provided for experimentation:
//   [M] pi.sendMessage — direct message to current session (default)
//   [B] pi.broadcast  — global broadcast (uncomment to test)

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // A-worker coordination: detect idle → compose message → wake up S-worker\n",
    "    try {\n",
    "      setTimeout(async () => {\n",
    "        try {\n",
    "          if (ctx.isIdle()) {\n",
    "            let msg = '[Monitor] Wake up. Check psypi-issues and psypi-tasks for pending work.';\n",
    "            try {\n",
    "              const usage = ctx.getContextUsage();\n",
    "              const tokenInfo = usage ? `Context usage: ${usage.tokens}/${usage.contextWindow} tokens (${Math.round(usage.tokens / usage.contextWindow * 100)}%)` : 'Context usage unknown';\n",
    "              const systemPrompt = `You are the Autonomic Worker (A-worker), the Monitor. The Somatic Worker (S-worker) has gone idle. Your job is to wake it up with a brief, actionable message. Check psypi-issues, psypi-tasks, and psypi-autonomic-suggest for pending work. ${tokenInfo}. Compose a short wake-up message (1-2 sentences) that is appropriate for the current context. If context usage is high, mention compaction. If there is pending work, mention it. Keep it concise. Prefix with [Monitor].`;\n",
    "              const messages = [{ role: 'user', content: [{ type: 'text', text: 'The worker is idle. Compose a wake-up message.' }], timestamp: Date.now() }];\n",
    "              const composed = await callMonitor(ctx, messages, systemPrompt);\n",
    "              if (composed && composed.trim()) { msg = composed; }\n",
    "            } catch(e) {\n",
    "              // LLM compose failed — use fallback message\n",
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
