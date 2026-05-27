import gleam/option.{type Option}

pub type ReviewType {
  Code
  Design
  Qc
  Peer
  Task
  Security
  System
  Other
}

pub type ReviewStatus {
  Pending
  InProgress
  Completed
  FollowUp
  Closed
}

pub type ReviewMethodology {
  DocumentAnalysis
  CodeComparison
  GitLog
  ConceptUnderstanding
  Mixed
}

pub type ReviewScope {
  Full
  Partial
  Focused
}

pub type FollowUpStatus {
  FuPending
  FuCompleted
  FuOverdue
}

pub type FindingSeverity {
  Critical
  High
  Medium
  Low
  Cosmetic
}

pub type FindingStatus {
  Open
  Confirmed
  Disputed
  Fixed
  WontFix
  Duplicate
  Retracted
}

pub type SystemReview {
  SystemReview(
    id: String,
    review_type: Option(ReviewType),
    status: ReviewStatus,
    current_state: Option(String),
    target_id: Option(String),
    target_type: Option(String),
    title: Option(String),
    description: Option(String),
    reviewer_id: Option(String),
    project_id: Option(String),
    methodology: Option(ReviewMethodology),
    scope: Option(ReviewScope),
    follow_up_status: FollowUpStatus,
    follow_up_due: Option(String),
    git_hash: Option(String),
    git_branch: Option(String),
    related_issue_id: Option(String),
    created_at: String,
    updated_at: String,
    completed_at: Option(String),
  )
}

pub type ReviewFinding {
  ReviewFinding(
    id: String,
    review_id: String,
    finding_number: Int,
    severity: FindingSeverity,
    category: String,
    module: Option(String),
    title: String,
    description: String,
    evidence: Option(String),
    impact: Option(String),
    status: FindingStatus,
    related_issue_id: Option(String),
    created_at: String,
    updated_at: String,
    resolved_at: Option(String),
  )
}

pub type ReviewError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

pub fn string_to_review_type(s: String) -> Result(ReviewType, String) {
  case s {
    "code" -> Ok(Code)
    "design" -> Ok(Design)
    "qc" -> Ok(Qc)
    "peer" -> Ok(Peer)
    "task" -> Ok(Task)
    "security" -> Ok(Security)
    "system" -> Ok(System)
    "other" -> Ok(Other)
    _ -> Error("Invalid review_type: " <> s)
  }
}

pub fn review_type_to_string(t: ReviewType) -> String {
  case t {
    Code -> "code"
    Design -> "design"
    Qc -> "qc"
    Peer -> "peer"
    Task -> "task"
    Security -> "security"
    System -> "system"
    Other -> "other"
  }
}

pub fn string_to_review_status(s: String) -> Result(ReviewStatus, String) {
  case s {
    "pending" -> Ok(Pending)
    "in_progress" -> Ok(InProgress)
    "completed" -> Ok(Completed)
    "follow_up" -> Ok(FollowUp)
    "closed" -> Ok(Closed)
    _ -> Error("Invalid review_status: " <> s)
  }
}

pub fn review_status_to_string(s: ReviewStatus) -> String {
  case s {
    Pending -> "pending"
    InProgress -> "in_progress"
    Completed -> "completed"
    FollowUp -> "follow_up"
    Closed -> "closed"
  }
}

pub fn string_to_methodology(s: String) -> Result(ReviewMethodology, String) {
  case s {
    "document_analysis" -> Ok(DocumentAnalysis)
    "code_comparison" -> Ok(CodeComparison)
    "git_log" -> Ok(GitLog)
    "concept_understanding" -> Ok(ConceptUnderstanding)
    "mixed" -> Ok(Mixed)
    _ -> Error("Invalid methodology: " <> s)
  }
}

pub fn methodology_to_string(m: ReviewMethodology) -> String {
  case m {
    DocumentAnalysis -> "document_analysis"
    CodeComparison -> "code_comparison"
    GitLog -> "git_log"
    ConceptUnderstanding -> "concept_understanding"
    Mixed -> "mixed"
  }
}

pub fn string_to_scope(s: String) -> Result(ReviewScope, String) {
  case s {
    "full" -> Ok(Full)
    "partial" -> Ok(Partial)
    "focused" -> Ok(Focused)
    _ -> Error("Invalid scope: " <> s)
  }
}

pub fn scope_to_string(s: ReviewScope) -> String {
  case s {
    Full -> "full"
    Partial -> "partial"
    Focused -> "focused"
  }
}

pub fn string_to_follow_up_status(s: String) -> Result(FollowUpStatus, String) {
  case s {
    "pending" -> Ok(FuPending)
    "completed" -> Ok(FuCompleted)
    "overdue" -> Ok(FuOverdue)
    _ -> Error("Invalid follow_up_status: " <> s)
  }
}

pub fn follow_up_status_to_string(s: FollowUpStatus) -> String {
  case s {
    FuPending -> "pending"
    FuCompleted -> "completed"
    FuOverdue -> "overdue"
  }
}

pub fn string_to_finding_severity(s: String) -> Result(FindingSeverity, String) {
  case s {
    "critical" -> Ok(Critical)
    "high" -> Ok(High)
    "medium" -> Ok(Medium)
    "low" -> Ok(Low)
    "cosmetic" -> Ok(Cosmetic)
    _ -> Error("Invalid finding severity: " <> s)
  }
}

pub fn finding_severity_to_string(s: FindingSeverity) -> String {
  case s {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
    Cosmetic -> "cosmetic"
  }
}

pub fn string_to_finding_status(s: String) -> Result(FindingStatus, String) {
  case s {
    "open" -> Ok(Open)
    "confirmed" -> Ok(Confirmed)
    "disputed" -> Ok(Disputed)
    "fixed" -> Ok(Fixed)
    "wont_fix" -> Ok(WontFix)
    "duplicate" -> Ok(Duplicate)
    "retracted" -> Ok(Retracted)
    _ -> Error("Invalid finding_status: " <> s)
  }
}

pub fn finding_status_to_string(s: FindingStatus) -> String {
  case s {
    Open -> "open"
    Confirmed -> "confirmed"
    Disputed -> "disputed"
    Fixed -> "fixed"
    WontFix -> "wont_fix"
    Duplicate -> "duplicate"
    Retracted -> "retracted"
  }
}
