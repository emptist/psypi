import gleam/int
import gleam/list

/// Calculate average of list of ints
pub fn average(ints: List(Int)) -> Result(Float, String) {
  case ints {
    [] -> Error("Empty list")
    _ -> {
      let total = int.sum(ints)
      let count = list.length(ints)
      Ok(int.to_float(total) /. int.to_float(count))
    }
  }
}

/// Check if number is prime (simplified)
pub fn is_prime(n: Int) -> Bool {
  case n < 2 {
    True -> False
    False -> is_prime_helper(n, 2)
  }
}

fn is_prime_helper(n: Int, divisor: Int) -> Bool {
  case divisor * divisor > n {
    True -> True
    False -> case n % divisor == 0 {
      True -> False
      False -> is_prime_helper(n, divisor + 1)
    }
  }
}

/// Convert radians to degrees
pub fn to_degrees(rad: Float) -> Float {
  rad *. 180.0 /. 3.1415926535
}
