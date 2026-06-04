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
            // ✅ CORRECT: Error reporting via pi_send_message. The auto-
            // backup read failure is an Error that must be persisted to
            // the conversation log; the local set_status below is a
            // status-line update for the TUI footer, NOT the Error
            // reporting channel.
            //   customType  = "autonomic-error"
            //   triggerTurn = False  ← do NOT wake S on a tool call error;
            //                          S will react when next legitimately
            //                          woken (e.g. on next A review, next
            //                          human input).
            //   deliverAs   = "followUp"
            // Waking S on a single file-read error would be the "panic
            // on any error" pattern the user has explicitly banned.
            Error(e) -> {
              let msg = "[FAIL] read: " <> e <> " | path: " <> file_path <> " | tool: " <> tool_name <> " | note: file exists on disk but FFI returned error — possible stale pi_extension_ffi.mjs in Node cache. Restart Pi TUI."
              set_status(ctx, "psypi-autobackup", msg)
              pi_send_message(pi, "autonomic-error", "[A-agentbot] Auto-backup read failed: " <> msg, "persistent", False, "followUp")
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
                    // ✅ CORRECT: Error reporting via pi_send_message.
                    // Same (customType, triggerTurn, deliverAs) contract
                    // as the read-failure branch above. Saving a code
                    // version to the DB failing is an Error — but S is
                    // not woken, because A is still in the middle of
                    // doing its work and will report again at the next
                    // agent_end if needed.
                    Error(e) -> {
                      let msg = "[FAIL] save_version: " <> string.inspect(e) <> " | path: " <> file_path
                      set_status(ctx, "psypi-autobackup", msg)
                      pi_send_message(pi, "autonomic-error", "[A-agentbot] Auto-backup save failed: " <> msg, "persistent", False, "followUp")
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
