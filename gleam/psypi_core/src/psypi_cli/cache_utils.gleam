import gleam/dict
import gleam/option
import gleam/result

pub type Cache(a) {
  Cache(store: dict.Dict(String, a), max_size: Int)
}

pub fn new(max_size: Int) -> Cache(a) {
  Cache(store: dict.new(), max_size: max_size)
}

pub fn get(cache: Cache(a), key: String) -> Result(a, Nil) {
  dict.get(cache.store, key)
}

pub fn put(cache: Cache(a), key: String, value: a) -> Cache(a) {
  let new_store = dict.insert(cache.store, key, value)
  // Simple eviction: if over size, clear (simplified)
  let size = dict.size(new_store)
  case size > cache.max_size {
    True -> Cache(store: dict.new() |> dict.insert(key, value), max_size: cache.max_size)
    False -> Cache(store: new_store, max_size: cache.max_size)
  }
}

pub fn clear(cache: Cache(a)) -> Cache(a) {
  Cache(store: dict.new(), max_size: cache.max_size)
}
