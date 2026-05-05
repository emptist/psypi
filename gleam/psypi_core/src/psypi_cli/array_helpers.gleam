import gleam/list
/// Chunk a list into groups of n
pub fn chunk(list: List(a), n: Int) -> List(List(a)) {
  chunk_helper(list, n, [])
}

fn chunk_helper(
  remaining: List(a),
  n: Int,
  acc: List(List(a)),
) -> List(List(a)) {
  case remaining {
    [] -> list.reverse(acc)
    _ -> {
      let chunk = list.take(remaining, n)
      let rest = list.drop(remaining, n)
      chunk_helper(rest, n, [chunk, ..acc])
    }
  }
}

/// Flatten a list of lists
pub fn flatten(lists: List(List(a))) -> List(a) {
  list.fold(lists, [], fn(acc, l) { list.append(acc, l) })
}

/// Find first element that satisfies predicate
pub fn find(
  list: List(a),
  predicate: fn(a) -> Bool,
) -> Result(a, Nil) {
  case list {
    [] -> Error(Nil)
    [head, ..rest] -> case predicate(head) {
      True -> Ok(head)
      False -> find(rest, predicate)
    }
  }
}
