/// Convert Gleam Result to display string (placeholder)
pub fn result_to_string(result: Result(a, e)) -> String {
  case result {
    Ok(_) -> "Ok"
    Error(_) -> "Error"
  }
}
