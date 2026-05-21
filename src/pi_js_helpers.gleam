// pi_js_helpers.gleam — JavaScript runtime helpers for Pi extension
//
// These functions return JS source text strings. They are NOT hand-written JS
// embedded in string literals — they are Gleam functions that emit JS text.

import gleam/list
import gleam/string

/// Generate the unwrapGleamResult helper function
/// This unwraps Gleam Result types (Ok/Error) into plain JS objects
pub fn unwrap_gleam_result() -> String {
  [
    "  function unwrapGleamResult(result) {",
    "    if (!result) return { ok: false, error: 'null result' };",
    "    const typeName = result.constructor?.name || '';",
    "    if (typeName === 'Ok') return { ok: true, value: result['0'] };",
    "    if (typeName === 'Error') return { ok: false, error: result['0']?.['0'] || result['0']?.toString() || 'Unknown' };",
    "    return { ok: true, value: result };",
    "  }",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}
