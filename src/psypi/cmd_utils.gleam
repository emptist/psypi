import gleam/javascript/promise

pub type CmdError {
  ExecutionError(String)
  TimeoutError
  NotFoundError(String)
}

@external(javascript, "./node_ffi.mjs", "execute")
pub fn execute(cmd: String) -> promise.Promise(Result(String, CmdError))

@external(javascript, "./node_ffi.mjs", "exists")
pub fn exists(cmd: String) -> promise.Promise(Bool)
