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
  let js_info = """
    const os = require('os');
    return {
      ok: true,
      value: {
        platform: os.platform(),
        node_version: process.version,
        cwd: process.cwd()
      }
    };
  """
  // Simplified - returns placeholder
  promise.resolve(SystemInfo(platform: "unknown", node_version: "unknown", cwd: ""))
}
