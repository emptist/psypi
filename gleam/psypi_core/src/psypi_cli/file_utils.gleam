import gleam/javascript/promise

pub type FileError {
  NotFound(String)
  ReadError(String)
  WriteError(String)
}

/// Read file contents (FFI)
pub fn read_file(path: String) -> promise.Promise(Result(String, FileError)) {
  let js_read = """
    try {
      const fs = require('fs');
      return { ok: true, value: fs.readFileSync('""" <> path <> """', 'utf-8') };
    } catch(e) {
      return { ok: false, value: e.message };
    }
  """
  // Simplified - returns placeholder
  promise.resolve(Error(NotFound("FFI not fully implemented")))
}

/// Write file contents (FFI)
pub fn write_file(path: String, content: String) -> promise.Promise(Result(Nil, FileError)) {
  // Simplified - returns placeholder
  promise.resolve(Error(WriteError("FFI not fully implemented")))
}
