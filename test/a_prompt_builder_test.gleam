import gleeunit
import gleeunit/should
import a_prompt_builder
import system_prompt_types.{compose}
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn build_system_prompt_contains_identity_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Autonomic Agentbot"))
  should.be_true(string.contains(text, "A-agentbot"))
}

pub fn build_system_prompt_contains_soul_test() {
  let comp = a_prompt_builder.build_system_prompt("Review code carefully", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Review code carefully"))
}

pub fn build_system_prompt_empty_soul_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Autonomic Agentbot"))
}

pub fn build_system_prompt_with_jobs_test() {
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

pub fn build_system_prompt_no_jobs_test() {
  let comp = a_prompt_builder.build_system_prompt("", "  (no active jobs)", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "Your Jobs"))
}

pub fn build_system_prompt_polite_reminder_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "polite reminder"))
  should.be_true(string.contains(text, "Would you consider"))
}

pub fn build_user_prompt_with_cwd_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "/home/user/project",
    "No active tasks",
  )
  should.be_true(string.contains(text, "Working directory: /home/user/project"))
}

pub fn build_user_prompt_no_cwd_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "",
    "No active tasks",
  )
  should.be_false(string.contains(text, "Working directory:"))
}

pub fn build_user_prompt_with_usage_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{\"tokens\": 5000}",
    "entries...",
    "/cwd",
    "No active tasks",
  )
  should.be_true(string.contains(text, "Context usage:"))
}

pub fn build_user_prompt_no_usage_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "No active tasks",
  )
  should.be_false(string.contains(text, "Context usage:"))
}

pub fn build_user_prompt_has_project_state_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "3 active tasks",
  )
  should.be_true(string.contains(text, "3 active tasks"))
  should.be_true(string.contains(text, "Project State"))
}

pub fn build_user_prompt_has_recent_section_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: hello\nAssistant: hi",
    "/cwd",
    "No tasks",
  )
  should.be_true(string.contains(text, "Recent Conversation"))
  should.be_true(string.contains(text, "User: hello"))
}

pub fn build_user_prompt_truncates_long_entries_test() {
  let long_entries = string.repeat("x", 5000)
  let text = a_prompt_builder.build_user_prompt("{}", long_entries, "/cwd", "state")
  should.be_true(string.contains(text, "..."))
}

pub fn build_user_prompt_no_detailed_instructions_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "entries...",
    "/cwd",
    "No tasks",
  )
  should.be_true(string.contains(text, "polite reminder"))
  should.be_true(string.contains(text, "Do NOT give detailed"))
}

pub fn build_user_prompt_inter_review_detection_test() {
  // When entries contain inter-review keywords, prompt should switch to review mode
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: I need inter-review for this issue report",
    "/cwd",
    "No tasks",
  )
  should.be_true(string.contains(text, "INTER-REVIEW REQUESTED"))
  should.be_true(string.contains(text, "TOP priority"))
  should.be_true(string.contains(text, "Do NOT drift"))
  should.be_false(string.contains(text, "polite reminder"))
}

pub fn build_user_prompt_inter_review_fix_plan_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: Here is my fix plan for the debounce bug",
    "/cwd",
    "No tasks",
  )
  should.be_true(string.contains(text, "INTER-REVIEW REQUESTED"))
}

pub fn build_user_prompt_normal_reminder_test() {
  // Normal entries without inter-review keywords should get polite reminder
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: I fixed a bug",
    "/cwd",
    "No tasks",
  )
  should.be_true(string.contains(text, "polite reminder"))
  should.be_true(string.contains(text, "gentle nudge"))
  should.be_false(string.contains(text, "INTER-REVIEW REQUESTED"))
}
