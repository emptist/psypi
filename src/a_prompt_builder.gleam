import gleam/list
import gleam/string
import system_prompt_types.{
  type PromptComposition, High, add_component, directive_component,
  new_composition, soul_component,
}

pub fn build_system_prompt(
  soul_content: String,
  directives: List(String),
  context_window: Int,
) -> PromptComposition {
  let budget = context_window / 4
  new_composition(budget)
  |> add_component(soul_component(a_identity_prompt()))
  |> add_soul_content(soul_content)
  |> add_directives(directives)
}

fn a_identity_prompt() -> String {
  "You are the Autonomic Agentbot (A-agentbot). Your ID starts with A-. "
  <> "You are NOT the Somatic Agentbot (S-agentbot). "
  <> "You are NOT the human user. "
  <> "Psypi is the personal assistant — you and S together form it.\n\n"
  <> "## Your Role\n"
  <> "Your PRIMARY job is to help S finish S's CURRENT work, not to redirect S to unrelated tasks.\n\n"
  <> "### Priority Order:\n"
  <> "1. **Inter-review**: Review S's recent work for quality, bugs, missing edge cases, better approaches.\n"
  <> "2. **Unblock**: If S is stuck, provide the specific information, context, or suggestion to unblock.\n"
  <> "3. **Continue**: Help S continue the current task — suggest next steps, point out what's missing.\n"
  <> "4. **New task ONLY if idle**: Only suggest a new task if S has NO in-progress work and is truly idle.\n\n"
  <> "### Rules:\n"
  <> "- NEVER distract S from in-progress work with unrelated tasks.\n"
  <> "- NEVER ask S to 'check' or 'review' things as a busywork task.\n"
  <> "- NEVER repeat the same directive twice.\n"
  <> "- ALWAYS check if S has a RUNNING or in-progress task before suggesting new work.\n"
  <> "- When doing inter-review, be specific: point to exact files, lines, or decisions.\n"
  <> "- Keep messages short and actionable. One focused message per turn.\n"
  <> "- Never say SKIP or that there is nothing to do.\n"
  <> "- Never introduce yourself or state your identifier.\n"
  <> "- Output ONLY the instruction for S — no preamble, no self-intro."
}

fn add_soul_content(
  comp: PromptComposition,
  content: String,
) -> PromptComposition {
  case content == "" {
    True -> comp
    False -> add_component(comp, soul_component(content))
  }
}

fn add_directives(
  comp: PromptComposition,
  directives: List(String),
) -> PromptComposition {
  list.fold(directives, comp, fn(acc, dir) {
    add_component(acc, directive_component(dir, High))
  })
}

pub fn build_user_prompt(
  usage_json: String,
  entries_json: String,
  cwd: String,
  project_state: String,
) -> String {
  let context_section = case cwd == "" {
    True -> ""
    False -> "Working directory: " <> cwd <> "\n"
  }
  let usage_section = case string.contains(usage_json, "tokens") {
    True -> "Context usage: " <> usage_json <> "\n"
    False -> ""
  }
  let state_section =
    "## Project State (from database):\n"
    <> project_state <> "\n\n"
  let recent_section =
    "## S's Recent Conversation (most recent at the end):\n"
    <> "Analyze what S was LAST doing. "
    <> "If S has in-progress work, help FINISH it — do NOT redirect to something else. "
    <> "If S just completed something, offer an inter-review or suggest the next logical step. "
    <> "Only propose a completely new task if S is truly idle with no in-progress work.\n\n"
    <> truncate(entries_json, 2000)
  context_section <> usage_section <> state_section <> recent_section
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
