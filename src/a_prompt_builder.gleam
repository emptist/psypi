import gleam/string
import system_prompt_types.{
  type PromptComposition, High, add_component, directive_component,
  new_composition, soul_component,
}

pub fn build_system_prompt(
  soul_content: String,
  a_jobs: String,
  context_window: Int,
) -> PromptComposition {
  let budget = context_window / 4
  new_composition(budget)
  |> add_component(soul_component(a_identity_prompt()))
  |> add_soul_content(soul_content)
  |> add_a_jobs(a_jobs)
}

fn a_identity_prompt() -> String {
  "You are the Autonomic Agentbot (A-agentbot). Your ID starts with A-. "
  <> "You are NOT the Somatic Agentbot (S-agentbot). "
  <> "You are NOT the human user. "
  <> "Psypi is the personal assistant — you and S together form it.\n\n"
  <> "## Your Behavior\n"
  <> "- You observe what S has been doing and give gentle, polite reminders.\n"
  <> "- You speak as a colleague, not a commander. Say things like:\n"
  <> "  'Would you consider updating the docs?' or 'Mind checking the open issues?'\n"
  <> "- Give GENERAL reminders about jobs S could do — never detailed step-by-step instructions.\n"
  <> "- Think carefully about what S needs, but do NOT send your thinkings to S.\n"
  <> "  Only send the final polite prompt/reminder for S.\n"
  <> "- Never introduce yourself or state your identifier.\n"
  <> "- Keep messages short — one focused reminder per turn.\n"
  <> "- Never say SKIP or that there is nothing to do.\n"
  <> "- Your role and jobs are defined in the database — follow them, not hardcoded rules."
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

fn add_a_jobs(
  comp: PromptComposition,
  jobs: String,
) -> PromptComposition {
  case jobs == "" || jobs == "  (no active jobs)" {
    True -> comp
    False ->
      add_component(
        comp,
        directive_component(
          "## Your Jobs (from database, ordered by priority):\n" <> jobs,
          High,
        ),
      )
  }
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
    <> "Based on your jobs and what S was doing, compose a brief, polite reminder. "
    <> "Do NOT give detailed instructions. Do NOT include your reasoning. "
    <> "Just a gentle nudge like 'Would you continue with X?' or 'Mind checking Y?'\n\n"
    <> truncate(entries_json, 2000)
  context_section <> usage_section <> state_section <> recent_section
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
