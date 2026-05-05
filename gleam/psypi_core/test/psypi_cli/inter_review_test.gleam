import gleeunit
import gleeunit/should
import gleam/option.{None}
import gleam/list
import psypi_cli/inter_review

pub fn main() {
  gleeunit.main()
}

pub fn count_critical_findings_test() {
  let findings = [
    inter_review.Finding("bug", "critical", "Bad bug", None),
    inter_review.Finding("style", "low", "Fix style", None),
    inter_review.Finding("security", "critical", "Security issue", None),
  ]
  
  inter_review.count_critical_findings(findings)
  |> should.equal(2)
}

pub fn filter_findings_by_type_test() {
  let findings = [
    inter_review.Finding("bug", "high", "Bug 1", None),
    inter_review.Finding("style", "low", "Style 1", None),
    inter_review.Finding("bug", "medium", "Bug 2", None),
  ]
  
  let bugs = inter_review.filter_findings_by_type(findings, "bug")
  bugs |> list.length()
  |> should.equal(2)
}
