import gleam/javascript/promise
import gleam/string
import gleam/list
import simplifile
import code_version
import pi_extension.{pi_send_message, set_status}
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
          case simplifile.read(file_path) {
            Error(e) -> {
              let msg = "[FAIL] read: " <> simplifile.describe_error(e) <> " | path: " <> file_path <> " | tool: " <> tool_name
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
