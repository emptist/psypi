import gleam/string
import gleam/int

pub fn format_date(year: Int, month: Int, day: Int) -> String {
  let y = int.to_string(year)
  let m = case month < 10 {
    True -> "0" <> int.to_string(month)
    False -> int.to_string(month)
  }
  let d = case day < 10 {
    True -> "0" <> int.to_string(day)
    False -> int.to_string(day)
  }
  y <> "-" <> m <> "-" <> d
}

pub fn is_valid_date(year: Int, month: Int, day: Int) -> Bool {
  case month < 1, month > 12 {
    True, _ -> False
    _, True -> False
    _, _ -> {
      let max_day = case month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
        4 | 6 | 9 | 11 -> 30
        2 -> case year % 4 == 0 {
          True -> 29
          False -> 28
        }
        _ -> 0
      }
      day >= 1 && day <= max_day
    }
  }
}
