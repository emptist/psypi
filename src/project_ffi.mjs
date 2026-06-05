// project_ffi.mjs — DEAD CODE, DO NOT USE
//
// ☠️ This file is no longer imported by any Gleam module.
// It previously cached the project URL in a module-level variable,
// which caused silent data corruption when the working directory changed.
//
// project_url() now reads simplifile.current_directory() fresh on every call.
// See project.gleam for the correct implementation.
//
// DO NOT REINTRODUCE CACHING. The working directory can change at any time.
// Every call to project_url() MUST read from the OS.

let _cachedProjectUrl = null;

export function get_project_url() {
  return _cachedProjectUrl;
}

export function set_project_url(url) {
  _cachedProjectUrl = url;
}
