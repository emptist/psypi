import gleam/javascript/promise
import psypi_cli/main_ffi.{spawn_pi}

pub fn main() {
  let args = ["--extension", "src/agent/extension/extension.mjs"]
  spawn_pi(args)
}
