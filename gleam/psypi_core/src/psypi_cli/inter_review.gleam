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
import gleam/javascript/promise
import gleam/option.{type Option, Some, None}
import gleam/list
import psypi_cli/db

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
  Learning(
    topic: String,
    reminder: String,
  )
}

pub type InterReviewError {
  ConnectionError(String)
  QueryError(String)
  ReviewFailed(String)
  NotFound(String)
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
  list.filter(findings, fn(f) {
    f.type_ == type_filter
  })
}

/// Request an inter-review (your code reviewed by Monitor AI)
/// Returns: Review ID string on success
pub fn request_review(
  task_id: Option(String),
  commit_hash: Option(String),
  reviewer_id: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT request_inter_review($1, $2, $3, $4, $5) as review_id
    "

    let task_id_str = case task_id {
      Some(id) -> id
      None -> ""
    }
    let commit_hash_str = case commit_hash {
      Some(h) -> h
      None -> ""
    }

    let params = [
      dynamic.string(task_id_str),
      dynamic.string(commit_hash_str),
      dynamic.string(reviewer_id),
      dynamic.string(""), // context as JSON
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_inter_review_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(QueryError("No review ID returned"))
            [row, ..] -> {
              // TODO: Extract review_id from row properly using dynamic.decode
              // For now, return placeholder
              Ok("review-id-placeholder")
            }
          }
        }
      }
    })
  }, db_error_to_inter_review_error)
}

/// Get review by ID
/// Returns: Review status string
pub fn get_review(
  review_id: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT status FROM inter_reviews WHERE id = $1"
    let params = [dynamic.string(review_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_inter_review_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(NotFound("Review not found: " <> review_id))
            [row, ..] -> {
              // TODO: Extract status from row properly
              // For now, return placeholder
              Ok("completed")
            }
          }
        }
      }
    })
  }, db_error_to_inter_review_error)
}

/// List reviews by status
/// Returns: List of review IDs
pub fn list_reviews(
  status: Option(String),
) -> promise.Promise(Result(List(String), InterReviewError)) {
  db.with_connection(fn(conn) {
    let sql = case status {
      Some(_) -> "SELECT id FROM inter_reviews WHERE status = $1 ORDER BY requested_at DESC LIMIT 100"
      None -> "SELECT id FROM inter_reviews ORDER BY requested_at DESC LIMIT 100"
    }

    let params = case status {
      Some(s) -> [dynamic.string(s)]
      None -> []
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_inter_review_error(e))
        Ok(result) -> {
          // TODO: Extract IDs from rows using list.map
          // For now, return empty list
          Ok([])
        }
      }
    })
  }, db_error_to_inter_review_error)
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
