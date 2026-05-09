import gleam/javascript/promise

pub type CmdResult {
  CmdResult(
    stdout: String,
    stderr: String,
    status: Int,
  )
}

pub type CmdError {
  ExecutionError(String)
  TimeoutError
}

@external(javascript, "./execute_cmd_ffi.mjs", "execute")
pub fn execute(cmd: String, timeout: Int) -> promise.Promise(Result(CmdResult, CmdError))

