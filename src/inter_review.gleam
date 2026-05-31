// inter_review.gleam — Inter-Review (A-bot autonomous code review)
//
// A-bot decides to do inter-review itself. Calls Monitor LLM to review code.
// Files result into inter_reviews table.
// No task binding. No request/pending flow. project_url is always from project_url().

import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import db
import project.{project_url}

pub type InterReviewError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_error(e: db.DbError) -> InterReviewError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

/// Save a completed inter-review result.
/// A-bot calls Monitor to review code, then files the result here.
pub fn save(
  summary: String,
  score: Int,
  findings: String,
  suggestions: String,
) -> promise.Promise(Result(String, InterReviewError)) {
  let project_url = project_url()
  db.with_connection(
    fn(conn) {
      let sql = "
        INSERT INTO inter_reviews (project_url, status, summary, overall_score, findings, suggestions, completed_at)
        VALUES ($1, 'completed', $2, $3, $4::jsonb, $5::jsonb, NOW())
        RETURNING id
      "
      let params = [
        dynamic.string(project_url),
        dynamic.string(summary),
        dynamic.int(score),
        dynamic.string(findings),
        dynamic.string(suggestions),
      ]
      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Error(e) -> Error(db_error_to_error(e))
          Ok(query_result) -> {
            case query_result.rows {
              [row, ..] -> {
                case decode.run(row, id_decoder()) {
                  Ok(id) -> Ok(id)
                  Error(_) -> Error(DecodeError("Failed to decode id"))
                }
              }
              _ -> Error(QueryError("No id returned"))
            }
          }
        }
      })
    },
    db_error_to_error,
  )
}
