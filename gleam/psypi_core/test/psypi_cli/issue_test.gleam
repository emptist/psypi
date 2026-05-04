import gleeunit/should
import psypi_cli/issue.{Pending, Active, Resolved, Closed}

pub fn issue_status_pending_test() {
  let status = Pending
  status
  |> should.equal(Pending)
}

pub fn issue_status_active_test() {
  let status = Active
  status
  |> should.equal(Active)
}

pub fn issue_status_resolved_test() {
  let status = Resolved
  status
  |> should.equal(Resolved)
}

pub fn issue_status_closed_test() {
  let status = Closed
  status
  |> should.equal(Closed)
}

// TODO: Add tests for Issue decoder if exported
// TODO: Add tests for issue.add, issue.list etc. with mocked data
