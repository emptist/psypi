// pi_system_prompt.gleam — System prompt injection for Pi extension
//
// Generates the before_agent_start hook that injects the S-agentbot role model
// into the system prompt.

import gleam/list
import gleam/string

/// Generate the before_agent_start hook body that returns the S-agentbot system prompt
pub fn before_agent_start_body() -> String {
  [
    "    return { systemPrompt: '\\n[A-S Role Model] You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. You are NOT the Autonomic Agentbot (A-agentbot). Messages prefixed with [A-agentbot] come from A — your coordinator. A directs you on what to work on. Follow A\\'s instructions as task assignments. The human user is the person operating the terminal.' };",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
