import gleam/string
import gleam/list

/// Join path segments
pub fn join(segments: List(String)) -> String {
  string.join(segments, "/")
}

/// Get file name from path
pub fn file_name(path: String) -> String {
  let parts = string.split(path, "/")
  case list.last(parts) {
    Ok(name) -> name
    Error(_) -> ""
  }
}

/// Get directory from path
pub fn dir_name(path: String) -> String {
  let parts = string.split(path, "/")
  let init_parts = list.take(parts, list.length(parts) - 1)
  string.join(init_parts, "/")
}

/// Check if path is absolute
pub fn is_absolute(path: String) -> Bool {
  string.starts_with(path, "/") || string.contains(path, ":/")
}
