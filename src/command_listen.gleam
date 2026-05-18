import gleam/javascript/promise
import pi_extension.{call_monitor, notify_info, pi_send_message}

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
      let system_prompt = "You are Monitor, a senior technical advisor. The human is communicating with you directly. Be concise and helpful."
      let user_prompt = args
      promise.map(
        call_monitor(ctx, user_prompt, system_prompt),
        fn(result) {
          case result {
            Ok(reply) -> {
              pi_send_message(pi, "autonomic-reply", "Monitor: " <> reply, "monitor")
              Ok(reply)
            }
            Error(e) -> {
              pi_send_message(pi, "autonomic-reply", "Monitor error: " <> e, "error")
              Error(e)
            }
          }
        },
      )
    }
  }
}
