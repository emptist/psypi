// generator/agent_lifecycle.gleam — Agent lifecycle hooks
// agent_end: A-worker checks if S-worker should be woken up
// Only wakes up if there are issues AND no active directives (S-worker is idle)

import gleam/list
import gleam/string

pub fn start_body() -> String {
  [
    "    // Autonomic: Track agent activity (silent)\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn end_body() -> String {
  [
    "    // AUTONOMIC: S-worker finished. Check if wake-up is needed.\n",
    "    try {\n",
    "      // 1. Check system health\n",
    "      const { check_system_health } = await import('./build/dev/javascript/psypi/monitor_ai.mjs');\n",
    "      const health = await check_system_health();\n",
    "      if (!health.ok) return;\n",
    "      const failed = health.value.failed_tasks;\n",
    "      const issues = health.value.open_issues;\n",
    "      if (failed === 0 && issues === 0) return; // All good, no wake-up needed\n",
    "\n",
    "      // 2. Check if directives already exist (S-worker is already working)\n",
    "      const identity = await agent_identity_get_resolved_identity(true, _sessionId, 'psypi', '', '', 'psypi', '');\n",
    "      const rId = unwrapGleamResult(identity);\n",
    "      if (!rId.ok) return;\n",
    "      const { get_active_directives } = await import('./build/dev/javascript/psypi/directive.mjs');\n",
    "      const dirsResult = await get_active_directives(rId.value.id);\n",
    "      const rDirs = unwrapGleamResult(dirsResult);\n",
    "      if (rDirs.ok && rDirs.value.length > 0) return; // Directives exist, S-worker is busy\n",
    "\n",
    "      // 3. Wake up S-worker with a question\n",
    "      const msg = '[Autonomic] System check: ' + failed + ' failed tasks, ' + issues + ' open issues. What should we work on next?';\n",
    "      pi.sendMessage({\n",
    "        customType: 'autonomic-prompt',\n",
    "        content: msg,\n",
    "        display: true,\n",
    "      }, { deliverAs: 'followUp' });\n",
    "    } catch(err) {\n",
    "      // Non-blocking\n",
    "    }\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
