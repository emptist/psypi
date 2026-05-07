import gleam/javascript/promise

// External function to spawn Pi via Node.js FFI
@external(javascript, "./main_ffi.mjs", "spawn_pi")
pub fn spawn_pi(args: List(String)) -> promise.Promise(Int)

// Main entry point
pub fn main(args: List(String)) -> promise.Promise(Int) {
  // Spawn Pi with given arguments
  spawn_pi(args)
}
