import gleam/javascript/promise
import gleam/string
import gleam/list
import code_version
import pi_extension.{read_file_sync, set_status}

fn extract_filename(path: String) -> String {
  let parts = string.split(path, "/")
  case list.last(parts) {
    Ok(name) -> name
    Error(_) -> path
  }
}

pub fn on_tool_call(
  tool_name: String,
  file_path: String,
  ctx: a,
) -> promise.Promise(Result(Nil, String)) {
  case tool_name == "edit" {
    False -> promise.resolve(Ok(Nil))
    True -> {
      case file_path == "" {
        True -> {
          set_status(ctx, "psypi-autobackup", "[SKIP] edit tool: empty file_path")
          promise.resolve(Ok(Nil))
        }
        False -> {
          case read_file_sync(file_path) {
            Error(e) -> {
              set_status(ctx, "psypi-autobackup", "[FAIL] read: " <> e)
              promise.resolve(Error("Read failed: " <> e))
            }
            Ok(content) -> {
              promise.map(
                code_version.save_version(file_path, content, "psypi", "", "auto-backup"),
                fn(result) {
                  case result {
                    Ok(_) -> {
                      let filename = extract_filename(file_path)
                      set_status(ctx, "psypi-autobackup", "Auto-backed up " <> filename)
                      Ok(Nil)
                    }
                    Error(e) -> {
                      set_status(ctx, "psypi-autobackup", "[FAIL] save_version: " <> string.inspect(e))
                      Error("save_version failed")
                    }
                  }
                },
              )
            }
          }
        }
      }
    }
  }
}
