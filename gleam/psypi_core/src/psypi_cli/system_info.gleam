import gleam/javascript/promise

pub type SystemInfo {
  SystemInfo(
    platform: String,
    node_version: String,
    cwd: String,
  )
}

/// Get system info (FFI)
pub fn get_info() -> promise.Promise(SystemInfo) {
  // TODO: Implement proper FFI for system info
  promise.resolve(SystemInfo(platform: "unknown", node_version: "unknown", cwd: ""))
}
