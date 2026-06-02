import gleam/int
import gleam/string
import system_prompt_types.{
  type PromptComposition, High, add_component, directive_component,
  new_composition, soul_component,
}

const default_review_score: Int = 50

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

/// Extract an integer score (0-100) from an LLM-generated review response.
///
/// The Monitor LLM is instructed (via soul + jobs) to include a line like
/// "Score: 75" or "Overall Score: 50" in its response. We scan for the first
/// such occurrence and parse the integer. If nothing is found, we return the
/// neutral default `default_review_score` (50). The result is clamped to
/// 0-100. This is the fix for RC-5 (2026-06-02): saves no longer carry
/// meaningless `0` scores that fire the broken auto-broadcast/auto-link
/// triggers.
pub fn parse_review_score(response: String) -> Int {
  let lower = string.lowercase(response)
  let candidates = [
    "overall score:", "overall score :", "score:",
    "score :", "rating:", "rating :",
  ]
  let parsed = find_and_parse_score(lower, candidates)
  case parsed {
    Ok(n) -> int.clamp(n, 0, 100)
    Error(_) -> default_review_score
  }
}

fn find_and_parse_score(
  haystack: String,
  needles: List(String),
) -> Result(Int, Nil) {
  case needles {
    [] -> Error(Nil)
    [first, ..rest] -> {
      case string.split_once(haystack, first) {
        Ok(after) -> parse_int_from_start(after.1)
        Error(_) -> find_and_parse_score(haystack, rest)
      }
    }
  }
}

fn parse_int_from_start(s: String) -> Result(Int, Nil) {
  let trimmed = string.trim(s)
  let #(sign, rest) = case string.first(trimmed) {
    Ok("-") -> #(-1, string.drop_start(trimmed, 1))
    _ -> #(1, trimmed)
  }
  let digits = take_leading_digits(rest)
  case digits {
    "" -> Error(Nil)
    _ ->
      case int.parse(digits) {
        Ok(n) -> Ok(n * sign)
        Error(_) -> Error(Nil)
      }
  }
}

fn take_leading_digits(s: String) -> String {
  case string.is_empty(s) {
    True -> ""
    False -> {
      let first = string.first(s)
      case first {
        Ok(c) -> {
          case int.parse(c) {
            Ok(_) ->
              c
              |> string.append(take_leading_digits(string.drop_start(s, 1)))
            Error(_) -> ""
          }
        }
        Error(_) -> ""
      }
    }
  }
}
