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
  let comp = a_prompt_builder.build_system_prompt("You are A-bot.", "", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "You are A-bot."))
}

pub fn build_system_prompt_empty_soul_omits_soul_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", "", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "--- soul"))
}

pub fn build_system_prompt_soul_appears_in_output_test() {
  let comp =
    a_prompt_builder.build_system_prompt("Review code carefully", "", "", 128000)
  let text = compose(comp)
  should.be_true(string.contains(text, "Review code carefully"))
}

// --- build_system_prompt: jobs ---

pub fn build_system_prompt_includes_jobs_test() {
  let comp = a_prompt_builder.build_system_prompt(
    "",
    "1. [review] Inter-review S code changes\n2. [unblock] Unblock stuck S jobs",
    "",
    128000,
  )
  let text = compose(comp)
  should.be_true(string.contains(text, "Inter-review S code changes"))
  should.be_true(string.contains(text, "Unblock stuck S jobs"))
  should.be_true(string.contains(text, "Your Jobs"))
}

pub fn build_system_prompt_no_jobs_omits_jobs_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", "", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "Your Jobs"))
}

pub fn build_system_prompt_placeholder_jobs_omits_jobs_section_test() {
  let comp = a_prompt_builder.build_system_prompt("", "  (no active jobs)", "", 128000)
  let text = compose(comp)
  should.be_false(string.contains(text, "Your Jobs"))
}

// --- build_system_prompt: budget ---

pub fn build_system_prompt_budget_is_quarter_of_context_window_test() {
  let comp = a_prompt_builder.build_system_prompt("", "", "", 128000)
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

pub fn build_user_prompt_empty_project_state_omits_section_test() {
  // When project_state is empty (e.g., autonomous inter-review path that
  // doesn't need to know about the whole project), the section header
  // must be omitted entirely, not just rendered with an empty body.
  let text = a_prompt_builder.build_user_prompt("{}", "entries...", "/cwd", "", "abc commit")
  should.be_false(string.contains(text, "Project State"))
  should.be_false(string.contains(text, "Project State (from database)"))
  // Other sections still appear
  should.be_true(string.contains(text, "Recent Commits"))
  should.be_true(string.contains(text, "Working directory"))
}

// --- build_user_prompt: recent conversation ---

pub fn build_user_prompt_includes_conversation_section_test() {
  let text = a_prompt_builder.build_user_prompt(
    "{}",
    "User: hello\nAssistant: hi",
    "/cwd",
    "No tasks",
    "",
  )
  // New header: section was renamed from "Recent Conversation" to
  // "Conversation" (commit 473e05b) to make clear A sees the full
  // session log, not a slice. The scope note is the new mechanism
  // for telling A where to focus the inter-review.
  should.be_true(string.contains(text, "S-bot's Conversation"))
  should.be_true(string.contains(text, "Scope note"))
  should.be_true(string.contains(text, "User: hello"))
}

pub fn build_user_prompt_does_not_truncate_long_entries_test() {
  let long_entries = string.repeat("x", 5000)
  let text = a_prompt_builder.build_user_prompt("{}", long_entries, "/cwd", "state", "")
  // No truncation marker should appear.
  should.be_false(string.contains(text, "...[truncated]"))
  // The full 5000-char entries must be present (head, not just tail).
  should.be_true(string.length(text) >= string.length(long_entries))
  // The head content (positions 0-99) must be present verbatim, not sliced off.
  should.be_true(string.contains(text, string.slice(long_entries, 0, 100)))
}

pub fn build_user_prompt_does_not_truncate_very_long_entries_test() {
  // Simulate a long S session log: 50_000 chars, bigger than the old 4000 cap by 12x.
  let huge_entries = string.repeat("a", 50_000)
  let text = a_prompt_builder.build_user_prompt("{}", huge_entries, "/cwd", "state", "")
  should.be_false(string.contains(text, "...[truncated]"))
  should.be_true(string.length(text) >= string.length(huge_entries))
  // Spot-check the very end: the most recent entries must be present.
  let tail_len = 200
  let head = string.drop_end(huge_entries, string.length(huge_entries) - tail_len)
  should.be_true(string.contains(text, head))
}

pub fn build_user_prompt_does_not_truncate_short_entries_test() {
  // Short input should be unchanged either way.
  let text = a_prompt_builder.build_user_prompt("{}", "User: hi\nAssistant: yo", "/cwd", "state", "")
  should.be_false(string.contains(text, "...[truncated]"))
  should.be_true(string.contains(text, "User: hi"))
  should.be_true(string.contains(text, "Assistant: yo"))
}

pub fn build_user_prompt_does_not_truncate_giant_commit_info_test() {
  // Commit info has no internal truncation either (it comes from get_recent_commits).
  // We assert the user_prompt does not apply any length cap of its own.
  let many_commits = string.repeat("abc1234 commit message line\n", 500)
  let text = a_prompt_builder.build_user_prompt("{}", "entries", "/cwd", "state", many_commits)
  // The commit section marker must be present.
  should.be_true(string.contains(text, "Recent Commits"))
  // The first commit's hash must be present (no head-only slice from the user_prompt).
  should.be_true(string.contains(text, "abc1234"))
  // The last commit's hash must be present (no tail-only slice from the user_prompt).
  should.be_true(string.contains(text, "abc1234 commit message line"))
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

// --- parse_review_score ---

pub fn parse_score_explicit_score_test() {
  should.equal(a_prompt_builder.parse_review_score("Summary here.\n\nScore: 75\n\nFindings..."), 75)
}

pub fn parse_score_overall_score_test() {
  should.equal(
    a_prompt_builder.parse_review_score("Inter-review of commit abc.\n\nOverall Score: 42\n\nFindings..."),
    42,
  )
}

pub fn parse_score_case_insensitive_test() {
  should.equal(
    a_prompt_builder.parse_review_score("Reply text.\n\nscore: 60\n"),
    60,
  )
}

pub fn parse_score_no_score_returns_default_50_test() {
  should.equal(
    a_prompt_builder.parse_review_score("Just a review with no score line at all."),
    50,
  )
}

pub fn parse_score_clamps_negative_to_zero_test() {
  should.equal(a_prompt_builder.parse_review_score("Score: -10\n"), 0)
}

pub fn parse_score_clamps_above_100_test() {
  should.equal(a_prompt_builder.parse_review_score("Score: 9999\n"), 100)
}

pub fn parse_score_handles_rating_label_test() {
  should.equal(
    a_prompt_builder.parse_review_score("Rating: 88\n\nLooks good."),
    88,
  )
}

pub fn parse_score_handles_realistic_llm_response_test() {
  let response = "
## Inter-Review Summary
The code change is well-structured but has a minor bug.

## Findings
1. [medium] Some issue
2. [low] Another issue

## Score: 65
## Next steps
- Fix the bug
"
  should.equal(a_prompt_builder.parse_review_score(response), 65)
}
