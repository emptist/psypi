// generator/agent_lifecycle.gleam — A-worker lifecycle hooks
//
// agent_end: S just finished working, A evaluates and prepares
// agent_start: S is starting, A stays silent

import gleam/list
import gleam/string

pub fn start_body() -> String {
  [
    "    // agent_start: S is starting, A stays silent\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

pub fn end_body() -> String {
  [
    "    // agent_end: S just finished, A evaluates\n",
    "    // S is now idle. A checks context and decides what to do.\n",
    "    ctx.ui.setStatus('psypi-autonomic', 'A-worker: S finished, evaluating...');\n",
    "    (async () => {\n",
    "      const wait = ms => new Promise(r => setTimeout(r, ms));\n",
    "      if (!ctx.isIdle()) return;\n",
    "      await wait(3000);\n",
    "      if (!ctx.isIdle()) return;\n",
    "      const usage = ctx.getContextUsage?.();\n",
    "      let msg = 'What should we do next?';\n",
    "      if (usage && usage.percent && usage.percent > 88) {\n",
    "        msg = 'Context usage high! Please update docs, capture learnings, and commit before compression.';\n",
    "      } else {\n",
    "        try {\n",
    "          const { execSync } = await import('child_process');\n",
    "          const status = execSync('git status --porcelain', { encoding: 'utf8' });\n",
    "          if (status.trim()) {\n",
    "            msg = 'You have uncommitted changes. Review the plan before committing?';\n",
    "          }\n",
    "        } catch (_) {}\n",
    "      }\n",
    "      ctx.ui.notify(msg, 'info');\n",
    "    })();\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
