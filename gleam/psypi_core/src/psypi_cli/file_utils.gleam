import simplifile
import gleam/javascript/promise

pub type FileError {
  NotFound(String)
  ReadError(String)
  WriteError(String)
}

/// Read file contents using simplifile (pure Gleam!)
pub fn read_file(path: String) -> promise.Promise(Result(String, FileError)) {
  let js_code =
    "const { Ok, Error } = require('../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/result.mjs');" <>
    "const simplifile = require('../../../gleam/psypi_core/build/dev/javascript/simplifile/simplifile.mjs');" <>
    "const result = simplifile.read('" <> path <> "');" <>
    "if (result.Ok !== undefined) return { ok: true, value: result.Ok };" <>
    "else return { ok: false, value: { ReadError: result.Error } };"
  
  promise.execute(js_code)
}

/// Write file contents using simplifile (pure Gleam!)
pub fn write_file(path: String, content: String) -> promise.Promise(Result(Nil, FileError)) {
  let js_code =
    "const { Ok, Error } = require('../../../gleam/psypi_core/build/dev/javascript/gleam_stdlib/gleam/result.mjs');" <>
    "const simplifile = require('../../../gleam/psypi_core/build/dev/javascript/simplifile/simplifile.mjs');" <>
    "const result = simplifile.write('" <> path <> "', '" <> content <> "');" <>
    "if (result.Ok !== undefined) return { ok: true, value: undefined };" <>
    "else return { ok: false, value: { WriteError: result.Error } };"
  
  promise.execute(js_code)
}
