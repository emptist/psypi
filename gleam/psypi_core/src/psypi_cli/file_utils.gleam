import simplifile
import gleam/result

pub type FileError {
  NotFound(String)
  ReadError(String)
  WriteError(String)
}

/// Read file contents using simplifile (pure Gleam!)
pub fn read_file(path: String) -> Result(String, FileError) {
  case simplifile.read(path) {
    Ok(content) -> Ok(content)
    Error(e) -> Error(ReadError(simplifile.describe_error(e)))
  }
}

/// Write file contents using simplifile (pure Gleam!)
pub fn write_file(path: String, content: String) -> Result(Nil, FileError) {
  case simplifile.write(path, content) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(WriteError(simplifile.describe_error(e)))
  }
}
