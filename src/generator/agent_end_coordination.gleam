// generator/agent_end_coordination.gleam — Idle detection + wake-up on agent_end
//
// When agent_end fires, wait 5 seconds, check ctx.isIdle(), and if still idle,
// send a [Monitor] message to the S-worker.
//
// Message composition — EXPERIMENTAL:
//   The A-worker tries to compose the message itself via LLM (callMonitor).
//   This may or may not work reliably — the LLM call could fail silently,
//   or the message quality may vary. If it doesn't work, we fall back to
//   a prepared list of messages selected programmatically based on context
//   (e.g., remaining tokens, pending work counts, etc.).
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
    "      // Wait 5 seconds, then check if still idle\n",
    "      setTimeout(async () => {\n",
    "        try {\n",
    "          if (ctx.isIdle()) {\n",
    "            // EXPERIMENT: Try LLM-composed message first\n",
    "            let msg = '[Monitor] Worker is idle. Check for pending work.';\n",
    "            try {\n",
    "              const systemPrompt = 'You are Monitor, the Autonomic Worker. The Somatic Worker has gone idle. Compose a brief, actionable wake-up message. Check psypi-issues, psypi-tasks, and psypi-autonomic-suggest for pending work. Keep it under 2 sentences. Prefix with [Monitor].';\n",
    "              const messages = [{ role: 'user', content: [{ type: 'text', text: 'The worker is idle. Compose a wake-up message.' }], timestamp: Date.now() }];\n",
    "              const composed = await callMonitor(ctx, messages, systemPrompt);\n",
    "              if (composed && composed.trim()) { msg = composed; }\n",
    "            } catch(e) {\n",
    "              // LLM compose failed — fall back to prepared message\n",
    "            }\n",
    "            // [M] Method 1: pi.sendMessage — direct message to current session\n",
    "            pi.sendMessage({\n",
    "              customType: 'monitor-wake-up',\n",
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
