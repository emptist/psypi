// gleam/psypi_core/src/psypi_core/review.gleam
// Inter-Review in Gleam - SIMPLE VERSION (returns String!)

// FFI declarations
@external(javascript, "./review_ffi.mjs", "run_review_ffi")
fn run_review_ffi(prompt: String) -> String

// Public API: Run inter-review (replaces InnerAgentExecutor)
// Returns: plain string (TypeScript can read it!)
pub fn run_review(prompt: String) -> String {
  run_review_ffi(prompt)
}
