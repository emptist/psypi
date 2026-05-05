import gleeunit/should
import gleam/dynamic/decode
import gleam/option.{Some, None}
import psypi_cli/issue.{
  Open, InProgress, Resolved, Closed, 
  Critical, High, Medium, Low, Cosmetic,
  Bug, Inconsistency, Feature,
  issue_decoder, id_decoder,
  string_to_severity, string_to_status, string_to_type
}
import psypi_cli/issue_test_helper

pub fn string_to_severity_critical_test() {
  string_to_severity("critical")
  |> should.equal(Critical)
}

pub fn string_to_severity_high_test() {
  string_to_severity("high")
  |> should.equal(High)
}

pub fn string_to_severity_medium_test() {
  string_to_severity("medium")
  |> should.equal(Medium)
}

pub fn string_to_severity_low_test() {
  string_to_severity("low")
  |> should.equal(Low)
}

pub fn string_to_severity_cosmetic_test() {
  string_to_severity("cosmetic")
  |> should.equal(Cosmetic)
}

pub fn string_to_severity_default_test() {
  string_to_severity("unknown")
  |> should.equal(Medium)
}

pub fn string_to_status_open_test() {
  string_to_status("open")
  |> should.equal(Open)
}

pub fn string_to_status_in_progress_test() {
  string_to_status("in_progress")
  |> should.equal(InProgress)
}

pub fn string_to_status_resolved_test() {
  string_to_status("resolved")
  |> should.equal(Resolved)
}

pub fn string_to_status_closed_test() {
  string_to_status("closed")
  |> should.equal(Closed)
}

pub fn string_to_status_default_test() {
  string_to_status("unknown")
  |> should.equal(Open)
}

pub fn string_to_type_bug_test() {
  string_to_type("bug")
  |> should.equal(Bug)
}

pub fn string_to_type_inconsistency_test() {
  string_to_type("inconsistency")
  |> should.equal(Inconsistency)
}

pub fn string_to_type_feature_test() {
  string_to_type("feature")
  |> should.equal(Feature)
}

pub fn issue_decoder_test() {
  let row = issue_test_helper.make_issue_row_1()
  let assert Ok(issue) = decode.run(row, issue_decoder())
  
  issue.id
  |> should.equal("issue-123")
  issue.title
  |> should.equal("Test Issue")
  issue.severity
  |> should.equal(High)
  issue.status
  |> should.equal(Open)
  issue.issue_type
  |> should.equal(Bug)
  issue.created_by
  |> should.equal("S-psypi-psypi")
}

pub fn issue_decoder_new_fields_test() {
  let row = issue_test_helper.make_issue_row_1()
  let assert Ok(issue) = decode.run(row, issue_decoder())
  
  issue.discovered_by
  |> should.equal(Some("nezha"))
  issue.environment
  |> should.equal(Some("development"))
  issue.git_branch
  |> should.equal(Some("main"))
  issue.git_hash
  |> should.equal(Some("abc123"))
  issue.reported_by
  |> should.equal(Some("nezha"))
  issue.source
  |> should.equal(Some("system"))
}

pub fn issue_decoder_new_fields_null_test() {
  let row = issue_test_helper.make_issue_row_2()
  let assert Ok(issue) = decode.run(row, issue_decoder())
  
  issue.discovered_by
  |> should.equal(None)
  issue.environment
  |> should.equal(None)
  issue.git_branch
  |> should.equal(None)
  issue.git_hash
  |> should.equal(None)
  issue.reported_by
  |> should.equal(None)
  issue.source
  |> should.equal(None)
}

pub fn id_decoder_test() {
  let row = issue_test_helper.make_id_row()
  let assert Ok(id) = decode.run(row, id_decoder())
  id
  |> should.equal("issue-789")
}
