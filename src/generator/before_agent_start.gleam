// generator/before_agent_start.gleam — Inject directives into system prompt
// Reads active directives from DB using Autonomic identity
// Adds [Autonomic] prefix so Somatic Worker knows who's directing

import gleam/list
import gleam/string

pub fn handler_body() -> String {
  [
    "    // AUTONOMIC → SOMATIC: Read directives from DB and inject into system prompt\n",
    "    try {\n",
    "      // 1. Get Autonomic identity (autonomous=true → A- prefix)\n",
    "      const identity = await agent_identity_get_resolved_identity(true, _sessionId, 'psypi', '', '', 'psypi', '');\n",
    "      const rId = unwrapGleamResult(identity);\n",
    "      if (!rId.ok) return;\n",
    "      const agentId = rId.value.id;\n",
    "\n",
    "      // 2. Read active directives from DB\n",
    "      const { get_active_directives, mark_directives_consumed } = await import('./build/dev/javascript/psypi/directive.mjs');\n",
    "      const dirsResult = await get_active_directives(agentId);\n",
    "      const rDirs = unwrapGleamResult(dirsResult);\n",
    "      if (!rDirs.ok || !rDirs.value.length) return;\n",
    "\n",
    "      // 3. Format with [Autonomic] prefix and inject\n",
    "      const directiveText = rDirs.value.map((d, i) => (i + 1) + '. [Autonomic] ' + d).join('\\n');\n",
    "      mark_directives_consumed(agentId).then(() => {}).catch(() => {});\n",
    "      ctx.ui.notify('[Autonomic] ' + rDirs.value.length + ' directive(s) injected', 'info');\n",
    "      return {\n",
    "        systemPrompt: event.systemPrompt + '\\n\\n[DIRECTIVES]\\n' + directiveText + '\\n[END DIRECTIVES]\\nAct on these directives before continuing with your own work.'\n",
    "      };\n",
    "    } catch(err) {\n",
    "      ctx.ui.notify('before_agent_start hook error: ' + err.message, 'error');\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
