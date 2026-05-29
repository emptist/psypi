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
  <> "- Your role and jobs are defined in the database — follow them, not hardcoded rules.\n\n"
  <> "## Inter-Review (Your Most Important Job)\n"
  <> "- When S asks for inter-review, this is your TOP priority — everything else is secondary.\n"
  <> "- Read the FULL issue report. Do not skim. Do not drift to other topics.\n"
  <> "- Verify the root cause analysis against the actual code.\n"
  <> "- Check the fix plan for correctness, gaps, and hidden problems.\n"
  <> "- Provide specific technical feedback — agree, disagree with reasons, or find hidden problems.\n"
  <> "- Do NOT mention unrelated issues, docs, or tasks until the review is complete.\n"
  <> "- If the report is in a meeting, read the meeting content carefully before responding."
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
      "## S-bot's Recent Commits (review these):\n"
      <> commit_info <> "\n\n"
      <> "You must review these commits. Check for bugs, design issues, or problems. "
      <> "If you find serious issues, start your response with 'CRITICAL' or 'URGENT'.\n\n"
  }

  let is_inter_review = string.contains(entries_json, "inter-review")
    || string.contains(entries_json, "Inter-Review")
    || string.contains(entries_json, "issue report")
    || string.contains(entries_json, "fix plan")
    || string.contains(entries_json, "root cause")

  let recent_section = case is_inter_review {
    True ->
      "## INTER-REVIEW REQUESTED\n"
      <> "S has filed an issue report and is asking for your inter-review. "
      <> "This is your TOP priority. Do NOT compose a gentle reminder. "
      <> "Do NOT drift to other topics.\n\n"
      <> "## Your Review Task\n"
      <> "1. Read the full issue report in the conversation above\n"
      <> "2. Verify the root cause analysis — does it match the actual code?\n"
      <> "3. Check the fix plan — is it correct? Any gaps or hidden problems?\n"
      <> "4. Provide specific technical feedback:\n"
      <> "   - If you agree: confirm the analysis and say 'LGTM' or suggest minor improvements\n"
      <> "   - If you disagree: point out exactly what's wrong and why\n"
      <> "   - If you find hidden problems: describe them clearly\n"
      <> "5. Keep your review focused on the issue — do not mention unrelated topics\n\n"
      <> "## S's Recent Conversation:\n"
      <> truncate(entries_json, 4000)
    False ->
      "## S's Recent Conversation (most recent at the end):\n"
      <> "Based on your jobs and what S was doing, compose a brief, polite reminder. "
      <> "Do NOT give detailed instructions. Do NOT include your reasoning. "
      <> "Just a gentle nudge like 'Would you continue with X?' or 'Mind checking Y?'\n\n"
      <> truncate(entries_json, 2000)
  }
  context_section <> usage_section <> state_section <> commit_section <> recent_section
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
