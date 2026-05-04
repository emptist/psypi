import gleeunit/should
import psypi_cli/skill.{Pending, Approved, Rejected, Blocked, Installed, Uninstalled}

pub fn skill_status_equality_test() {
  // Test that SkillStatus constructors work
  let pending = Pending
  let approved = Approved
  let rejected = Rejected
  let blocked = Blocked
  let installed = Installed
  let uninstalled = Uninstalled
  
  // Simple equality checks (they are different constructors)
  pending
  |> should.not_equal(approved)
  
  approved
  |> should.not_equal(rejected)
  
  rejected
  |> should.not_equal(blocked)
  
  blocked
  |> should.not_equal(installed)
  
  installed
  |> should.not_equal(uninstalled)
}

// TODO: Add more tests for skill decoder if exported
// TODO: Add tests for skill.list, skill.get etc. with mocked data
