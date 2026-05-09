import gleam/javascript/promise

pub type PackageInfo {
  PackageInfo(
    name: String,
    version: String,
    description: String,
  )
}

pub type PackageError {
  NotFound
  ReadError(String)
}

/// Read package.json (FFI)
pub fn read_package_json() -> promise.Promise(Result(PackageInfo, PackageError)) {
  // TODO: Implement proper FFI for reading package.json
  // Simplified - returns placeholder
  promise.resolve(Error(NotFound))
}
