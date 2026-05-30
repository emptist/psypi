// issue_types.gleam — Issue types and converters

import gleam/option.{type Option}

pub type IssueSeverity {
  Critical
  High
  Medium
  Low
  Cosmetic
}

pub type IssueStatus {
  Open
  Acknowledged
  InProgress
  Resolved
  WontFix
  Duplicate
}

pub type IssueType {
  Bug
  Inconsistency
  Feature
  Improvement
  Question
  Debt
  Proposal
}

pub type Issue {
  Issue(
    id: String,
    title: String,
    description: Option(String),
    severity: IssueSeverity,
    status: IssueStatus,
    issue_type: IssueType,
    created_at: String,
    resolved_at: Option(String),
    created_by: String,
    discovered_by: Option(String),
    environment: Option(String),
    git_branch: Option(String),
    git_hash: Option(String),
    reported_by: Option(String),
    source: Option(String),
  )
}

pub type IssueError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

pub type IssueComment {
  IssueComment(
    id: String,
    issue_id: String,
    author: String,
    content: String,
    is_internal: Bool,
    created_at: String,
  )
}

pub fn string_to_severity(s: String) -> Result(IssueSeverity, String) {
  case s {
    "critical" -> Ok(Critical)
    "high" -> Ok(High)
    "medium" -> Ok(Medium)
    "low" -> Ok(Low)
    "cosmetic" -> Ok(Cosmetic)
    _ -> Error("Invalid severity: " <> s <> ". Allowed: critical, high, medium, low, cosmetic")
  }
}

pub fn string_to_status(s: String) -> Result(IssueStatus, String) {
  case s {
    "open" -> Ok(Open)
    "acknowledged" -> Ok(Acknowledged)
    "in_progress" -> Ok(InProgress)
    "resolved" -> Ok(Resolved)
    "wont_fix" -> Ok(WontFix)
    "duplicate" -> Ok(Duplicate)
    _ -> Error("Invalid status: " <> s <> ". Allowed: open, acknowledged, in_progress, resolved, wont_fix, duplicate")
  }
}

pub fn string_to_type(t: String) -> Result(IssueType, String) {
  case t {
    "bug" -> Ok(Bug)
    "inconsistency" -> Ok(Inconsistency)
    "feature" -> Ok(Feature)
    "improvement" -> Ok(Improvement)
    "question" -> Ok(Question)
    "debt" -> Ok(Debt)
    "proposal" -> Ok(Proposal)
    _ -> Error("Invalid issue_type: " <> t <> ". Allowed: bug, inconsistency, feature, improvement, question, debt, proposal")
  }
}

pub fn severity_to_string(s: IssueSeverity) -> String {
  case s {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
    Cosmetic -> "cosmetic"
  }
}

pub fn type_to_string(t: IssueType) -> String {
  case t {
    Bug -> "bug"
    Inconsistency -> "inconsistency"
    Feature -> "feature"
    Improvement -> "improvement"
    Question -> "question"
    Debt -> "debt"
    Proposal -> "proposal"
  }
}
