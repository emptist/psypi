import gleam/int
import gleam/list
import gleam/order.{type Order}
import gleam/option.{type Option, None, Some}
import gleam/string

pub type PromptPriority {
  Critical
  High
  Medium
  Low
}

pub type PromptComponentKind {
  Soul
  Directive
  Skill
  ContextFile
  Custom(String)
}

pub type PromptComponent {
  PromptComponent(
    kind: PromptComponentKind,
    priority: PromptPriority,
    content: String,
    estimated_tokens: Int,
    source: Option(String),
  )
}

pub type ContextBudget {
  ContextBudget(
    total_tokens: Int,
    used_tokens: Int,
  )
}

pub type PromptComposition {
  PromptComposition(
    components: List(PromptComponent),
    budget: ContextBudget,
  )
}

pub fn budget_available(budget: ContextBudget) -> Int {
  budget.total_tokens - budget.used_tokens
}

pub fn budget_percent(budget: ContextBudget) -> Float {
  case budget.total_tokens == 0 {
    True -> 0.0
    False ->
      int.to_float(budget.used_tokens) /. int.to_float(budget.total_tokens)
        *. 100.0
  }
}

pub fn estimate_tokens(text: String) -> Int {
  string.length(text) / 4 + 1
}

pub fn priority_value(priority: PromptPriority) -> Int {
  case priority {
    Critical -> 1
    High -> 2
    Medium -> 3
    Low -> 4
  }
}

pub fn priority_to_string(priority: PromptPriority) -> String {
  case priority {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
  }
}

pub fn string_to_priority(s: String) -> PromptPriority {
  case s {
    "critical" -> Critical
    "high" -> High
    "medium" -> Medium
    _ -> Low
  }
}

pub fn kind_to_string(kind: PromptComponentKind) -> String {
  case kind {
    Soul -> "soul"
    Directive -> "directive"
    Skill -> "skill"
    ContextFile -> "context"
    Custom(name) -> name
  }
}

pub fn new_composition(total_tokens: Int) -> PromptComposition {
  PromptComposition(
    components: [],
    budget: ContextBudget(total_tokens:, used_tokens: 0),
  )
}

pub fn add_component(
  comp: PromptComposition,
  component: PromptComponent,
) -> PromptComposition {
  PromptComposition(
    components: [component, ..comp.components],
    budget: ContextBudget(
      total_tokens: comp.budget.total_tokens,
      used_tokens: comp.budget.used_tokens + component.estimated_tokens,
    ),
  )
}

fn compare_by_priority(
  a: PromptComponent,
  b: PromptComponent,
) -> Order {
  int.compare(priority_value(a.priority), priority_value(b.priority))
}

pub fn compose(comp: PromptComposition) -> String {
  let sorted = list.sort(comp.components, compare_by_priority)
  sorted
  |> list.map(fn(c) {
    "--- "
    <> kind_to_string(c.kind)
    <> " ["
    <> priority_to_string(c.priority)
    <> "] ---\n"
    <> c.content
  })
  |> string.join("\n\n")
}

pub fn compose_within_budget(
  comp: PromptComposition,
) -> PromptComposition {
  let sorted = list.sort(comp.components, compare_by_priority)
  let #(kept, _) =
    list.fold(sorted, #([], 0), fn(acc, component) {
      let #(components, tokens) = acc
      let new_tokens = tokens + component.estimated_tokens
      case new_tokens > comp.budget.total_tokens {
        True -> #(components, tokens)
        False -> #([component, ..components], new_tokens)
      }
    })
  let used =
    list.fold(kept, 0, fn(acc, c) { acc + c.estimated_tokens })
  PromptComposition(
    components: kept,
    budget: ContextBudget(
      total_tokens: comp.budget.total_tokens,
      used_tokens: used,
    ),
  )
}

pub fn soul_component(content: String) -> PromptComponent {
  PromptComponent(
    kind: Soul,
    priority: Critical,
    content:,
    estimated_tokens: estimate_tokens(content),
    source: None,
  )
}

pub fn directive_component(
  content: String,
  priority: PromptPriority,
) -> PromptComponent {
  PromptComponent(
    kind: Directive,
    priority:,
    content:,
    estimated_tokens: estimate_tokens(content),
    source: None,
  )
}

pub fn skill_component(content: String) -> PromptComponent {
  PromptComponent(
    kind: Skill,
    priority: Medium,
    content:,
    estimated_tokens: estimate_tokens(content),
    source: None,
  )
}

pub fn context_component(
  content: String,
  path: String,
) -> PromptComponent {
  PromptComponent(
    kind: ContextFile,
    priority: Low,
    content:,
    estimated_tokens: estimate_tokens(content),
    source: Some(path),
  )
}
