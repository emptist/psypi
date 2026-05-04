import gleam/javascript/promise

pub type CmdError {
  ExecutionError(String)
  TimeoutError
  NotFoundError(String)
}

/// Execute shell command (FFI)
pub fn execute(cmd: String) -> promise.Promise(Result(String, CmdError)) {
  let js_exec = """
    const { execSync } = require('child_process');
    try {
      const output = execSync('""" <> cmd <> """', { encoding: 'utf-8', timeout: 30000 });
      return { ok: true, value: output };
    } catch(e) {
      return { ok: false, value: e.message };
    }
  """
  // Simplified - returns placeholder
  promise.resolve(Error(ExecutionError("FFI not fully implemented")))
}

/// Check if command exists
pub fn exists(cmd: String) -> promise.Promise(Bool) {
  let js_which = """
    const { execSync } = require('child_process');
    try {
      execSync('which ' + '""" <> cmd <> """', { stdio: 'ignore' });
      return true;
    } catch(e) {
      return false;
    }
  """
  // Simplified - returns false
  promise.resolve(False)
}
