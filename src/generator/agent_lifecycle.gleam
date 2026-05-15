// generator/agent_lifecycle.gleam — A‑worker lifecycle hooks
// NOTE (2026‑05‑15):
// * The Autonomic worker (A‑worker) must be aware that it is running in
//   autonomous mode. This is needed so it can apply A‑specific logic
//   (e.g., idle checks, usage‑based prompts) only when the identity
//   resolves to an ID starting with "A-".
// * The current implementation resolves its own identity via the
//   `agent_identity.get_resolved_identity` Gleam tool with `autonomous = true`
//   and aborts the hook if the resulting ID does not start with "A-".
// * Keeping this check lightweight avoids any side‑effects on the S‑worker's
//   context. If future tests show the check is unnecessary (e.g., the hook
//   only ever runs for A‑worker), the code can be simplified back to the
//   original version.
// * This comment serves as a reference for why the extra identity lookup
//   exists and can be removed if the implementation proves redundant.
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
    "    // Removed UI status update – A speaks only via system prompt\n",
    "    (async () => { // Ensure this is running as the Autonomic worker (A‑worker)
      // Compute own identity – autonomous flag must be true
      const { get_resolved_identity } = await import('./build/dev/javascript/psypi/agent_identity.mjs');
      const aIdRes = await get_resolved_identity(true, 'psypi', 'psypi', (ctx.model?.id || ''), (ctx.model?.thinkingLevel || ''));
      if (!aIdRes) return; // not able to resolve – bail out
      // aIdRes is a Gleam result – unwrap to see if it’s ok
      const unwrap = (r) => {
        if (!r) return null;
        const tn = r.constructor?.name;
        if (tn === 'Ok') return r['0'];
        return null;
      };
      const aId = unwrap(aIdRes);
      if (!aId || !aId.id || !aId.id.startsWith('A-')) return; // not the A‑worker, skip
\n",
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
    "      // Debug: show A‑worker message in the UI (info level)
      ctx.ui.notify(msg, 'info');\n",
    "    })();\n",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
