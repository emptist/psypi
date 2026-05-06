// Test if .js (not .mjs) works
import gleam/io

// Using .js extension (as user suggested)
@external(javascript, "./helpers.js", "greet")
fn greet_from_js(name: String) -> String

pub fn main() {
  io.println("Testing .js extension (not .mjs)...")
  let result = greet_from_js("Gleam User")
  io.println(result)
}
