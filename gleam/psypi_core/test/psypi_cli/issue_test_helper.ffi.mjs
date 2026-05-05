// FFI helper for creating issue test data
// This creates JavaScript objects that simulate PostgreSQL query results

export function makeIssueRow1() {
  return {
    id: "issue-123",
    title: "Test Issue",
    description: "A test issue",
    severity: "high",
    status: "open",
    issue_type: "bug",
    created_at: "2026-05-04T00:00:00Z",
    resolved_at: null,
    created_by: "S-psypi-psypi",
    discovered_by: "nezha",
    environment: "development",
    git_branch: "main",
    git_hash: "abc123",
    reported_by: "nezha",
    source: "system",
  };
}

export function makeIssueRow2() {
  return {
    id: "issue-456",
    title: "Resolved Issue",
    description: null,
    severity: "medium",
    status: "resolved",
    issue_type: "feature",
    created_at: "2026-05-04T00:00:00Z",
    resolved_at: "2026-05-04T01:00:00Z",
    created_by: "S-psypi-psypi",
    discovered_by: null,
    environment: null,
    git_branch: null,
    git_hash: null,
    reported_by: null,
    source: null,
  };
}

export function makeIdRow() {
  return { id: "issue-789" };
}
