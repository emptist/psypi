import gleam/javascript/promise
import pi_extension.{notify_info, pi_send_message}

pub fn on_autonomic_listen(
  args: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  case args == "" {
    True -> {
      notify_info(ctx, "Usage: /autonomic-listen <message>")
      promise.resolve(Ok("Usage: /autonomic-listen <message>"))
    }
    False -> {
      let listen_msg = "[from A-worker:] DIRECT MESSAGE TO MONITOR\n\n"
        <> "The human says: " <> args
        <> "\n\nRespond as Monitor — a senior technical advisor. Be concise and helpful."
      notify_info(ctx, "[AUTONOMIC] Forwarding human message to S-worker as Monitor directive")
      pi_send_message(pi, "autonomic-wakeup", listen_msg, "persistent")
      promise.resolve(Ok("Message forwarded to S-worker. The S-worker will respond as Monitor."))
    }
  }
}
