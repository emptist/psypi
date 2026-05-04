import gleam/list
import gleam/string
import gleam/int
import gleam/result

pub fn filter_map(
  items: List(a),
  filter_fn: fn(a) -> Bool,
  map_fn: fn(a) -> b,
) -> List(b) {
  items
  |> list.filter(filter_fn)
  |> list.map(map_fn)
}

pub fn group_by(
  items: List(a),
  key_fn: fn(a) -> String,
) -> List(#(String, List(a))) {
  let keys = items |> list.map(key_fn) |> list.unique
  list.map(keys, fn(key) {
    let grouped = list.filter(items, fn(item) { key_fn(item) == key })
    #(key, grouped)
  })
}

pub fn sum_by(
  items: List(a),
  value_fn: fn(a) -> Int,
) -> Int {
  items
  |> list.map(value_fn)
  |> int.sum()
}
