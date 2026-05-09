import gleam/javascript/promise

pub type CmdError {
  ExecutionError(String)
  TimeoutError
  NotFoundError(String)
}

@external(javascript, "./cmd_utils_ffi.mjs", "execute")
pub fn execute(cmd: String) -> promise.Promise(Result(String, CmdError))

@external(javascript, "./cmd_utils_ffi.mjs", "exists")
pub fn exists(cmd: String) -> promise.Promise(Bool)
