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
  |> add_soul_content(soul_content)
  |> add_a_jobs(a_jobs)
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
  commit_info: String,
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

  let commit_section = case commit_info == "" {
    True -> ""
    False ->
      "## S-bot's Recent Commits:\n"
      <> commit_info <> "\n\n"
  }

  let recent_section =
    "## S-bot's Recent Conversation (most recent at the end):\n"
    <> truncate(entries_json, 4000)

  context_section <> usage_section <> state_section <> commit_section <> recent_section
}

fn truncate(s: String, max: Int) -> String {
  let len = string.length(s)
  case len > max {
    True ->
      "...[truncated] "
      |> string.append(string.slice(s, len - max, max))
    False -> s
  }
}
