// inter_review.gleam - Inter-Review logic (correctly named!)
// Small + Pure = Resilience!
//
// Inter-Review: Your code reviewed by another AI (Monitor/God)
// (Different from system-review which is general project review)
//
// NOTE: Previous coders incorrectly named this "review.gleam"
// - review.gleam = system review (general)
// - inter_review.gleam = inter-review (specific: code reviewed by another AI)
//
// Learned patterns from ../refers/gleam:
// - Use case expressions with pattern matching
// - Use recursive functions for list processing
// - Add documentation with /// comments
// - Use Result type for error handling

import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi/db

pub type ReviewResult {
  ReviewResult(
    summary: String,
    score: Int,
    findings: List(ReviewFinding),
    learnings: List(Learning),
  )
}

pub type ReviewFinding {
  Finding(
    type_: String,
    severity: String,
    message: String,
    suggestion: Option(String),
  )
}

pub type Learning {
  Learning(topic: String, reminder: String)
}

pub type Review {
  Review(
    id: String,
    task_id: Option(String),
    status: String,
    summary: Option(String),
    overall_score: Option(Int),
    requested_at: String,
  )
}

pub type InterReviewError {
  ConnectionError(String)
  QueryError(String)
  ReviewFailed(String)
  NotFound(String)
  DecodeError(String)
}

// Error mapper for db.with_connection
fn db_error_to_inter_review_error(e: db.DbError) -> InterReviewError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Count critical findings in a list
/// (Learned from gleam/list.gleam patterns)
pub fn count_critical_findings(findings: List(ReviewFinding)) -> Int {
  list.count(findings, fn(f) {
    case f.severity {
      "critical" -> True
      _ -> False
    }
  })
}

/// Filter findings by type
/// (Using list.filter pattern from stdlib)
pub fn filter_findings_by_type(
  findings: List(ReviewFinding),
  type_filter: String,
) -> List(ReviewFinding) {
  list.filter(findings, fn(f) { f.type_ == type_filter })
}

/// Decoder for Review type
fn review_decoder() -> decode.Decoder(Review) {
  use id <- decode.field("id", decode.string)
  use task_id <- decode.field("task_id", decode.optional(decode.string))
  use status <- decode.field("status", decode.string)
  use summary <- decode.field("summary", decode.optional(decode.string))
  use overall_score <- decode.field(
    "overall_score",
    decode.optional(decode.int),
  )
  use requested_at <- decode.field("requested_at", decode.string)
  decode.success(Review(
    id:,
    task_id:,
    status:,
    summary:,
    overall_score:,
    requested_at:,
  ))
}

/// Decoder for review_id (returned by request_inter_review SQL function)
fn review_id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("review_id", decode.string)
  decode.success(id)
}

/// Decoder for review status
fn status_decoder() -> decode.Decoder(String) {
  use status <- decode.field("status", decode.string)
  decode.success(status)
}

/// Get full review details by ID
/// Returns: Review record with all fields
pub fn get_review_details(
  review_id: String,
) -> promise.Promise(Result(Review, InterReviewError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews WHERE id = $1"
      let params = [dynamic.string(review_id)]

      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_inter_review_error(e))
          Ok(result) -> {
            case result.rows {
              [] -> Error(NotFound("Review not found: " <> review_id))
              [row, ..] -> {
                case decode.run(row, review_decoder()) {
                  Ok(review) -> Ok(review)
                  Error(_) -> Error(DecodeError("Failed to decode review"))
                }
              }
            }
          }
        }
      })
    },
    db_error_to_inter_review_error,
  )
}

/// Request an inter-review (your code reviewed by Monitor AI)
/// Returns: Review ID string on success
pub fn request_review(
  task_id: Option(String),
  commit_hash: Option(String),
  reviewer_id: String,
  context: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      SELECT request_inter_review($1, $2, $3, $4, $5) as review_id
    "

      let task_id_param = case task_id {
        Some(id) -> dynamic.string(id)
        None -> dynamic.string("")
      }
      let commit_hash_param = case commit_hash {
        Some(h) -> dynamic.string(h)
        None -> dynamic.string("")
      }
      // reviewer_id: 永远来自 get_resolved_identity(permanent=true)
      let reviewer_id_param = dynamic.string(reviewer_id)

      // p_branch - get from git or use empty string
      let branch = "main"
      // TODO: get from git
      let branch_str = dynamic.string(branch)

      // context needs to be valid JSON for jsonb parameter
      // Use gleam_json (pure Gleam!) to encode properly
      let context_json =
        json.to_string(
          json.object([
            #("text", json.string(context)),
            #("source", json.string("psypi-inter-review-request")),
          ]),
        )
      let context_json_str = dynamic.string(context_json)

      let params = [
        task_id_param,
        commit_hash_param,
        branch_str,
        reviewer_id_param,
        context_json_str,
      ]

      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_inter_review_error(e))
          Ok(result) -> {
            case result.rows {
              [] -> Error(QueryError("No review ID returned"))
              [row, ..] -> {
                case decode.run(row, review_id_decoder()) {
                  Ok(review_id) -> Ok(review_id)
                  Error(_) -> Error(DecodeError("Failed to decode review_id"))
                }
              }
            }
          }
        }
      })
    },
    db_error_to_inter_review_error,
  )
}

/// Get review by ID
/// Returns: Review status string
pub fn get_review(
  review_id: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  db.with_connection(
    fn(conn) {
      let sql = "SELECT status FROM inter_reviews WHERE id = $1"
      let params = [dynamic.string(review_id)]

      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_inter_review_error(e))
          Ok(result) -> {
            case result.rows {
              [] -> Error(NotFound("Review not found: " <> review_id))
              [row, ..] -> {
                case decode.run(row, status_decoder()) {
                  Ok(status) -> Ok(status)
                  Error(_) -> Error(DecodeError("Failed to decode status"))
                }
              }
            }
          }
        }
      })
    },
    db_error_to_inter_review_error,
  )
}

/// List reviews by status
/// Returns: List of Review with details
pub fn list_reviews(
  status: Option(String),
) -> promise.Promise(Result(List(Review), InterReviewError)) {
  db.with_connection(
    fn(conn) {
      let sql = case status {
        Some(_) ->
          "SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews WHERE status = $1 ORDER BY requested_at DESC LIMIT 100"
        None ->
          "SELECT id, task_id, status, summary, overall_score, requested_at FROM inter_reviews ORDER BY requested_at DESC LIMIT 100"
      }

      let params = case status {
        Some(s) -> [dynamic.string(s)]
        None -> []
      }

      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_inter_review_error(e))
          Ok(result) -> {
            let reviews =
              result.rows
              |> list.map(fn(row) {
                case decode.run(row, review_decoder()) {
                  Ok(review) -> [review]
                  Error(_) -> []
                }
              })
              |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
            Ok(reviews)
          }
        }
      })
    },
    db_error_to_inter_review_error,
  )
}

/// Check if review is complete
/// Returns: True if status is "completed"
pub fn is_review_complete(
  review_id: String,
) -> promise.Promise(Result(Bool, InterReviewError)) {
  promise.map(get_review(review_id), fn(result) {
    case result {
      Error(e) -> Error(e)
      Ok(status) -> {
        case status {
          "completed" -> Ok(True)
          _ -> Ok(False)
        }
      }
    }
  })
}
