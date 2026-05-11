import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import db

pub type ValidationResult {
  ValidationResult(
    valid: Bool,
    error: String,
  )
}

pub type ValidationError {
  QueryError(String)
}

fn db_error_to_validation_error(e: db.DbError) -> ValidationError {
  case e {
    db.ConnectionError(msg) -> QueryError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn validation_result_decoder() -> decode.Decoder(ValidationResult) {
  use has_brackets <- decode.field("has_brackets", decode.bool)
  use has_uuid <- decode.field("has_uuid", decode.bool)
  let valid = has_brackets || has_uuid
  let error = case valid {
    True -> ""
    False -> "Commit message should contain [task/issue] or UUID"
  }
  decode.success(ValidationResult(valid:, error:))
}

/// Validate commit message format
pub fn validate(
  message: String,
) -> promise.Promise(Result(ValidationResult, ValidationError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 
        CASE 
          WHEN $1 ~ '^\\[.*\\]$' THEN true
          ELSE false
        END as has_brackets,
        CASE 
          WHEN $1 ~ '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' THEN true
          ELSE false
        END as has_uuid
    "
    let params = [dynamic.string(message)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_validation_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, validation_result_decoder()) {
                Ok(vr) -> Ok(vr)
                Error(_) -> Error(QueryError("Failed to decode validation result"))
              }
            }
            _ -> Error(QueryError("No result returned"))
          }
        }
      }
    })
  }, db_error_to_validation_error)
}
