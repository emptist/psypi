// error_utils.gleam - Error handling utilities
// Learned: gleam/string not needed if not used
// Gleam will warn about unused imports

pub type AppError {
  DatabaseError(String)
  ValidationError(String)
  NotFoundError(String)
  PermissionError(String)
}

/// Convert error to human-readable string
pub fn error_to_string(error: AppError) -> String {
  case error {
    DatabaseError(msg) -> "Database Error: " <> msg
    ValidationError(msg) -> "Validation Error: " <> msg
    NotFoundError(msg) -> "Not Found: " <> msg
    PermissionError(msg) -> "Permission Denied: " <> msg
  }
}

/// Check if error is retryable
pub fn is_retryable(error: AppError) -> Bool {
  case error {
    DatabaseError(_) -> True
    ValidationError(_) -> False
    NotFoundError(_) -> False
    PermissionError(_) -> False
  }
}
