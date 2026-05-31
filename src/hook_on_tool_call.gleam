import gleam/javascript/promise
import gleam/string
import gleam/list
import code_version
import pi_extension.{pi_send_message, read_file_sync, set_status}
import psypi_config

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
  pi: a,
) -> promise.Promise(Result(Nil, String)) {
  let _ = psypi_config.set("idle_since", "0")
  case tool_name == "edit" {
    False -> promise.resolve(Ok(Nil))
    True -> {
      case file_path == "" {
        True -> promise.resolve(Ok(Nil))
        False -> {
          case read_file_sync(file_path) {
            Error(e) -> {
              let msg = "[FAIL] read: " <> e <> " | path: " <> file_path <> " | tool: " <> tool_name <> " | note: file exists on disk but FFI returned error — possible stale pi_extension_ffi.mjs in Node cache. Restart Pi TUI."
              set_status(ctx, "psypi-autobackup", msg)
              pi_send_message(pi, "autonomic-error", "[A-agentbot] Auto-backup read failed: " <> msg, "persistent")
              promise.resolve(Error(msg))
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
                      let msg = "[FAIL] save_version: " <> string.inspect(e) <> " | path: " <> file_path
                      set_status(ctx, "psypi-autobackup", msg)
                      pi_send_message(pi, "autonomic-error", "[A-agentbot] Auto-backup save failed: " <> msg, "persistent")
                      Error(msg)
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
