// ppi_gen.gleam - Pure Gleam entry point for psypi
// Generates extension.js then spawns Pi with correct cwd
// Run with: gleam run -m ppi_gen [args...]

import extension_generator
import gleam/javascript/promise

@external(javascript, "./node_ffi.mjs", "spawn_pi")
pub fn spawn_pi(args: List(String)) -> promise.Promise(Int)

@external(javascript, "./node_ffi.mjs", "get_cli_args")
pub fn get_cli_args() -> List(String)

pub fn main() -> promise.Promise(Int) {
  extension_generator.write_extension()
  spawn_pi(get_cli_args())
}