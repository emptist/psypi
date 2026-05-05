import gleam/javascript/promise

pub type CmdError {
  ExecutionError(String)
  TimeoutError
  NotFoundError(String)
}

/// Execute shell command using FFI (Node.js child_process)
/// Note: Pure Gleam alternative doesn't exist for Node.js process execution
pub fn execute(cmd: String) -> promise.Promise(Result(String, CmdError)) {
  let js_code = 
    "try {" <>
    "  const { execSync } = require('child_process');" <>
    "  const output = execSync('" <> cmd <> "', { encoding: 'utf-8', timeout: 30000 });" <>
    "  return { ok: true, value: output };" <>
    "} catch(e) {" <>
    "  return { ok: false, value: e.message };" <>
    "}"
  
  promise.execute(js_code)
}

/// Check if command exists
pub fn exists(cmd: String) -> promise.Promise(Bool) {
  let js_code =
    "try {" <>
    "  const { execSync } = require('child_process');" <>
    "  execSync('which ' + '" <> cmd <> "', { stdio: 'ignore' });" <>
    "  return true;" <>
    "} catch(e) {" <>
    "  return false;" <>
    "}"
  
  promise.execute(js_code)
}
