import gleeunit
import gleeunit/should
import a_context_utils

pub fn main() {
  gleeunit.main()
}

pub fn parse_context_window_valid_test() {
  a_context_utils.parse_context_window("{\"contextWindow\":128000,\"used\":5000}")
  |> should.equal(Ok(128000))
}

pub fn parse_context_window_no_key_test() {
  a_context_utils.parse_context_window("{\"used\":5000}")
  |> should.be_error()
}

pub fn parse_context_window_empty_test() {
  a_context_utils.parse_context_window("")
  |> should.be_error()
}

pub fn parse_context_window_with_spaces_test() {
  a_context_utils.parse_context_window("{\"contextWindow\": 64000}")
  |> should.equal(Ok(64000))
}

pub fn parse_context_window_large_value_test() {
  a_context_utils.parse_context_window("{\"contextWindow\":2000000}")
  |> should.equal(Ok(2_000_000))
}
