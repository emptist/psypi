import gleam/int

pub fn safe_divide(a: Float, b: Float) -> Result(Float, String) {
  case b == 0.0 {
    True -> Error("Division by zero")
    False -> Ok(a /. b)
  }
}

pub fn percentage(part: Int, total: Int) -> Result(Float, String) {
  case total == 0 {
    True -> Error("Total cannot be zero")
    False -> Ok(int.to_float(part) /. int.to_float(total) *. 100.0)
  }
}

pub fn clamp(value: Int, min: Int, max: Int) -> Int {
  case value < min {
    True -> min
    False -> case value > max {
      True -> max
      False -> value
    }
  }
}
