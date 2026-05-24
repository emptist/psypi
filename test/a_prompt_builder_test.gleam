import gleeunit
import gleeunit/should
import a_prompt_builder
import system_prompt_types.{compose}
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn build_system_prompt_contains_identity_test() {
  let comp = a_prompt_builder.build_system_prompt("", [], 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Autonomic Agentbot"))
  should.be_true(string.contains(text, "A-agentbot"))
}

pub fn build_system_prompt_contains_soul_test() {
  let comp = a_prompt_builder.build_system_prompt("Review code carefully", [], 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Review code carefully"))
}

pub fn build_system_prompt_empty_soul_test() {
  let comp = a_prompt_builder.build_system_prompt("", [], 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Autonomic Agentbot"))
}

pub fn build_system_prompt_with_directives_test() {
  let comp = a_prompt_builder.build_system_prompt("", ["Fix bug #42", "Review PR"], 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Fix bug #42"))
  should.be_true(string.contains(text, "Review PR"))
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
