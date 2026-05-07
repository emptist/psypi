import gleeunit/should
import psypi_cli/broadcast.{priority_to_string, string_to_priority, Low, Normal, High, Critical}

pub fn priority_to_string_low_test() {
  priority_to_string(Low)
  |> should.equal("low")
}

pub fn priority_to_string_normal_test() {
  priority_to_string(Normal)
  |> should.equal("normal")
}

pub fn priority_to_string_high_test() {
  priority_to_string(High)
  |> should.equal("high")
}

pub fn priority_to_string_critical_test() {
  priority_to_string(Critical)
  |> should.equal("critical")
}

pub fn string_to_priority_low_test() {
  string_to_priority("low")
  |> should.equal(Low)
}

pub fn string_to_priority_normal_test() {
  string_to_priority("normal")
  |> should.equal(Normal)
}

pub fn string_to_priority_high_test() {
  string_to_priority("high")
  |> should.equal(High)
}

pub fn string_to_priority_critical_test() {
  string_to_priority("critical")
  |> should.equal(Critical)
}

pub fn string_to_priority_default_test() {
  // Test default case
  string_to_priority("unknown")
  |> should.equal(Low) // Based on implementation: _ -> Low
}
