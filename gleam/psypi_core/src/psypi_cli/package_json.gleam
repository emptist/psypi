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
  let js_read = """
    try {
      const fs = require('fs');
      const data = fs.readFileSync('package.json', 'utf-8');
      const json = JSON.parse(data);
      return { 
        ok: true, 
        value: {
          name: json.name || '',
          version: json.version || '',
          description: json.description || ''
        }
      };
    } catch(e) {
      return { ok: false, value: e.message };
    }
  """
  // Simplified - returns placeholder
  promise.resolve(Error(NotFound))
}
