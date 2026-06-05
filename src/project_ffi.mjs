// project_ffi.mjs — FFI for project_url caching
//
// Caches the project URL in a module-level variable.
// Read once from disk, reused for the lifetime of the process.

let _cachedProjectUrl = null;

export function get_project_url() {
  return _cachedProjectUrl;
}

export function set_project_url(url) {
  _cachedProjectUrl = url;
}
