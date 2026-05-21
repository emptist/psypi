// time_utils_ffi.mjs — JavaScript FFI for time_utils.gleam

export function now_iso8601() {
  return Promise.resolve(new Date().toISOString());
}
