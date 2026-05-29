import gleam/javascript/promise
import gleam/string
import pi_extension.{exec_sync, get_agent_id}

fn shell_escape(s: String) -> String {
  s
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("`", "\\`")
  |> string.replace("$", "\\$")
}

pub fn on_commit(
  message: String,
  ctx: a,
  _pi: b,
) -> promise.Promise(Result(String, String)) {
  let agent_id = get_agent_id(ctx)
  let tagged_message = case agent_id {
    "" -> message
    id -> message <> " [AI:" <> id <> "]"
  }
  let escaped = shell_escape(tagged_message)
  let cmd = "git add -A && git commit -m \"" <> escaped <> "\""
  case exec_sync(cmd) {
    Ok(_) -> promise.resolve(Ok("Committed: " <> tagged_message))
    Error(e) -> promise.resolve(Error("git commit failed: " <> e))
  }
}
