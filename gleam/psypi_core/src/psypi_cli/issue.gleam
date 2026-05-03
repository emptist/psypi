// issue.gleam - Issue management (~50 lines)
// Small + Pure = Resilience!



pub type IssueError {
  DatabaseError(String)
  NotFound(String)
}

pub fn add_issue(title: String, severity: String) -> Result(String, IssueError) {
  // TODO: Call PostgreSQL via FFI
  Ok("Issue created: " <> title)
}

pub fn list_issues(status: String) -> Result(String, IssueError) {
  // TODO: Query issues from DB
  Ok("Issues listed")
}

pub fn resolve_issue(issue_id: String, resolution: String) -> Result(String, IssueError) {
  // TODO: Update issue status
  Ok("Issue resolved: " <> issue_id)
}
