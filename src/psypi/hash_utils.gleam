import gleam/javascript/promise

pub type HashResult {
  HashResult(
    md5: String,
    sha1: String,
    sha256: String,
  )
}

pub type HashError {
  NotSupported
}

/// Calculate hashes (FFI placeholder)
pub fn calculate_hashes(_input: String) -> promise.Promise(Result(HashResult, HashError)) {
  // Simplified - returns placeholder
  let result = HashResult(
    md5: "dummy_md5",
    sha1: "dummy_sha1",
    sha256: "dummy_sha256"
  )
  promise.resolve(Ok(result))
}
