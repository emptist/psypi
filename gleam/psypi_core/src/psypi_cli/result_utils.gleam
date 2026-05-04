import gleam/result
import gleam/list

pub fn map_ok(
  result: Result(a, e),
  mapper: fn(a) -> b,
) -> Result(b, e) {
  case result {
    Ok(value) -> Ok(mapper(value))
    Error(err) -> Error(err)
  }
}

pub fn map_error(
  result: Result(a, e),
  mapper: fn(e) -> f,
) -> Result(a, f) {
  case result {
    Ok(value) -> Ok(value)
    Error(err) -> Error(mapper(err))
  }
}

pub fn combine_results(
  results: List(Result(a, e)),
) -> Result(List(a), e) {
  let fold_fn = fn(acc: Result(List(a), e), r: Result(a, e)) {
    case acc, r {
      Ok(acc_list), Ok(value) -> Ok([value, ..acc_list])
      Error(e), _ -> Error(e)
      _, Error(e) -> Error(e)
    }
  }
  let reversed = list.fold(results, Ok([]), fold_fn)
  case reversed {
    Ok(list) -> Ok(list.reverse(list))
    Error(e) -> Error(e)
  }
}
