import gleeunit
import gleeunit/should
import system_prompt_types.{
  Critical, High, Low, Medium,
  add_component, budget_available, budget_percent, compose,
  compose_within_budget, context_component, directive_component,
  estimate_tokens, kind_to_string, new_composition, priority_to_string,
  priority_value, skill_component, soul_component, string_to_priority,
}
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn estimate_tokens_test() {
  estimate_tokens("hello") |> should.equal(2)
  estimate_tokens("") |> should.equal(1)
  estimate_tokens("a") |> should.equal(1)
  estimate_tokens("abcdefgh") |> should.equal(3)
}

pub fn priority_value_ordering_test() {
  priority_value(Critical) |> should.equal(1)
  priority_value(High) |> should.equal(2)
  priority_value(Medium) |> should.equal(3)
  priority_value(Low) |> should.equal(4)
}

pub fn priority_roundtrip_test() {
  priority_to_string(Critical) |> string_to_priority() |> should.equal(Critical)
  priority_to_string(High) |> string_to_priority() |> should.equal(High)
  priority_to_string(Medium) |> string_to_priority() |> should.equal(Medium)
  priority_to_string(Low) |> string_to_priority() |> should.equal(Low)
}

pub fn string_to_priority_default_test() {
  string_to_priority("unknown") |> should.equal(Low)
}

pub fn kind_to_string_test() {
  kind_to_string(system_prompt_types.Soul) |> should.equal("soul")
  kind_to_string(system_prompt_types.Directive) |> should.equal("directive")
  kind_to_string(system_prompt_types.Skill) |> should.equal("skill")
  kind_to_string(system_prompt_types.ContextFile) |> should.equal("context")
  kind_to_string(system_prompt_types.Custom("custom")) |> should.equal("custom")
}

pub fn new_composition_budget_test() {
  let comp = new_composition(1000)
  comp.budget.total_tokens |> should.equal(1000)
  comp.budget.used_tokens |> should.equal(0)
  budget_available(comp.budget) |> should.equal(1000)
}

pub fn add_component_updates_budget_test() {
  let comp =
    new_composition(1000)
    |> add_component(soul_component("Hello world"))
  should.be_true(comp.budget.used_tokens > 0)
  budget_available(comp.budget) |> should.equal(1000 - comp.budget.used_tokens)
}

pub fn compose_empty_test() {
  new_composition(1000) |> compose |> should.equal("")
}

pub fn compose_single_component_test() {
  let text =
    new_composition(1000)
    |> add_component(soul_component("You are helpful"))
    |> compose
  should.be_true(string.contains(text, "You are helpful"))
  should.be_true(string.contains(text, "soul"))
}

pub fn compose_priority_ordering_test() {
  let text =
    new_composition(10000)
    |> add_component(directive_component("Low priority", Low))
    |> add_component(soul_component("Soul content"))
    |> add_component(directive_component("High priority", High))
    |> compose
  let soul_pos = position_of(text, "Soul content")
  let high_pos = position_of(text, "High priority")
  let low_pos = position_of(text, "Low priority")
  should.be_true(soul_pos < high_pos)
  should.be_true(high_pos < low_pos)
}

fn position_of(haystack: String, needle: String) -> Int {
  case string.split(haystack, needle) {
    [before, ..] -> string.length(before)
    _ -> -1
  }
}

pub fn compose_within_budget_test() {
  let comp =
    new_composition(10)
    |> add_component(soul_component(string.repeat("x", 100)))
    |> add_component(directive_component("short", Critical))
    |> compose_within_budget
  let _text = compose(comp)
  should.be_true(comp.budget.used_tokens <= 10)
}

pub fn budget_percent_test() {
  let comp = new_composition(1000)
  budget_percent(comp.budget) |> should.equal(0.0)
}

pub fn budget_percent_with_usage_test() {
  let comp =
    new_composition(1000)
    |> add_component(soul_component(string.repeat("a", 400)))
  let pct = budget_percent(comp.budget)
  should.be_true(pct >. 0.0)
}

pub fn skill_component_test() {
  let comp =
    new_composition(1000)
    |> add_component(skill_component("Search the web"))
  let text = compose(comp)
  should.be_true(string.contains(text, "Search the web"))
  should.be_true(string.contains(text, "skill"))
}

pub fn context_component_test() {
  let comp =
    new_composition(1000)
    |> add_component(context_component("File contents", "/path/to/file"))
  let text = compose(comp)
  should.be_true(string.contains(text, "File contents"))
  should.be_true(string.contains(text, "context"))
}
