import gleeunit/should
import psypi_cli/broadcast.{priority_to_int, int_to_priority, Low, Normal, High, Urgent}

pub fn priority_to_int_low_test() {
  priority_to_int(Low)
  |> should.equal(0)
}

pub fn priority_to_int_normal_test() {
  priority_to_int(Normal)
  |> should.equal(1)
}

pub fn priority_to_int_high_test() {
  priority_to_int(High)
  |> should.equal(2)
}

pub fn priority_to_int_urgent_test() {
  priority_to_int(Urgent)
  |> should.equal(3)
}

pub fn int_to_priority_0_test() {
  int_to_priority(0)
  |> should.equal(Low)
}

pub fn int_to_priority_1_test() {
  int_to_priority(1)
  |> should.equal(Normal)
}

pub fn int_to_priority_2_test() {
  int_to_priority(2)
  |> should.equal(High)
}

pub fn int_to_priority_3_test() {
  int_to_priority(3)
  |> should.equal(Urgent)
}

pub fn int_to_priority_default_test() {
  // Test default case (not 0,1,2,3)
  int_to_priority(99)
  |> should.equal(Low) // Based on implementation: _ -> Low
}
