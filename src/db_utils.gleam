// db_utils.gleam — Shared database utility functions
//
// This module extracts common patterns that were previously duplicated
// across multiple modules (agents, event_hooks, issue_db, meeting,
// system_review_db, task, a_db_reader, s_db_reader, broadcast).
//
// - decode_all_results: Collects a list of Results, short-circuiting on Error
// - decode_rows: Decodes a list of dynamic rows using a decoder, with
//   customizable error mapping

import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/result
import gleam/string

/// Collects a list of Results into a Result of List, short-circuiting
/// on the first Error. All copies across the codebase are identical.
///
/// Previously duplicated in: agents.gleam, event_hooks.gleam, issue_db.gleam,
/// meeting.gleam, system_review_db.gleam, task.gleam
pub fn decode_all_results(results: List(Result(a, b))) -> Result(List(a), b) {
  case results {
    [] -> Ok([])
    [Ok(v), ..rest] -> {
      case decode_all_results(rest) {
        Error(e) -> Error(e)
        Ok(vs) -> Ok([v, ..vs])
      }
    }
    [Error(e), .._] -> Error(e)
  }
}

/// Decodes a list of dynamic rows using the provided decoder.
/// Maps decode errors through the provided error constructor.
///
/// Previously duplicated as private fns in: a_db_reader.gleam, s_db_reader.gleam
/// broadcast.gleam had a similar but BroadcastError-specific variant.
pub fn decode_rows(
  rows: List(dynamic.Dynamic),
  decoder: decode.Decoder(a),
  error_mapper: fn(String) -> b,
) -> Result(List(a), b) {
  rows
  |> list.map(fn(row) {
    decode.run(row, decoder)
    |> result.map_error(fn(e) { error_mapper("decode: " <> string.inspect(e)) })
  })
  |> decode_all_results
}
