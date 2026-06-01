import gleeunit
import gleeunit/should
import a_prompt_builder
import system_prompt_types.{compose}
import gleam/string

pub fn main() {
  gleeunit.main()
}

// --- build_system_prompt: soul content ---

pub fn build_system_prompt_includes_soul_test() {
  let comp = a_prompt_builder.build_system_prompt("You are A-bot.", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "You are A-bot."))
}

pub fn build_system_prompt_empty_soul_omits_soul_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "--- soul"))
}

pub fn build_system_prompt_soul_appears_in_output_test() {
  let comp =
    a_prompt_builder.build_system_prompt("Review code carefully", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Review code carefully"))
}

// --- build_system_prompt: jobs ---

pub fn build_system_prompt_includes_jobs_test() {
  let comp = a_prompt_builder.build_system_prompt(
    "",
    "1. [review] Inter-review S code changes\n2. [unblock] Unblock stuck S jobs",
    128000,
  )
  let text = compose(comp)
  should.be_true(string.contains(text, "Inter-review S code changes"))
  should.be_true(string.contains(text, "Unblock stuck S jobs"))
  should.be_true(string.contains(text, "Your Jobs"))
}

pub fn build_system_prompt_no_jobs_omits_jobs_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "Your Jobs"))
}

pub fn build_system_prompt_placeholder_jobs_omits_jobs_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "  (no active jobs)", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "Your Jobs"))
}

// --- build_system_prompt: budget ---

pub fn build_system_prompt_budget_is_quarter_of_context_window_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  comp.budget.total_tokens |> should.equal(32000)
}

// --- build_user_prompt: cwd ---

pub fn build_user_prompt_with_cwd_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "/home/user/project",
    "No active tasks",
    "",
  )
  should.be_true(string.contains(text, "Working directory: /home/user/project"))
}

pub fn build_user_prompt_empty_cwd_omits_working_directory_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "",
    "No active tasks",
    "",
  )
  should.be_false(string.contains(text, "Working directory:"))
}

// --- build_user_prompt: context usage ---

pub fn build_user_prompt_with_usage_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "/cwd",
    "No active tasks",
    "",
  )
  should.be_true(string.contains(text, "Context usage:"))
}

pub fn build_user_prompt_empty_usage_omits_context_usage_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "No active tasks",
    "",
  )
  should.be_false(string.contains(text, "Context usage:"))
}

// --- build_user_prompt: project state ---

pub fn build_user_prompt_includes_project_state_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "3 active tasks",
    "",
  )
  should.be_true(string.contains(text, "3 active tasks"))
  should.be_true(string.contains(text, "Project State"))
}

// --- build_user_prompt: recent conversation ---

pub fn build_user_prompt_includes_recent_conversation_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: hello\nAssistant: hi",
    "/cwd",
    "No tasks",
    "",
  )
  should.be_true(string.contains(text, "Recent Conversation"))
  should.be_true(string.contains(text, "User: hello"))
}

pub fn build_user_prompt_truncates_long_entries_test() {
  let long_entries = string.repeat("x", 5000)
  let text = a_prompt_builder.build_user_prompt("{}", long_entries, "/cwd", "state", "")
  should.be_true(string.contains(text, "...[truncated]"))
  // Original was 5000 chars; truncated output must be shorter
  should.be_true(string.length(text) < string.length(long_entries))
}

// --- build_user_prompt: commit info ---

pub fn build_user_prompt_with_commit_info_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "No tasks",
    "abc123 fix: debounce bug\ndef456 feat: add review",
  )
  should.be_true(string.contains(text, "Recent Commits"))
  should.be_true(string.contains(text, "debounce bug"))
}

pub fn build_user_prompt_empty_commit_info_omits_commits_section_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "No tasks",
    "",
  )
  should.be_false(string.contains(text, "Recent Commits"))
}
