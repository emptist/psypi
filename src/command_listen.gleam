import gleam/javascript/promise
import pi_extension.{
  call_monitor, notify_info, pi_send_message,
}

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
      let system_prompt =
        "You are the Autonomic Agentbot (A-agentbot). Your ID starts with A-. "
        <> "You are NOT the Somatic Agentbot (S-agentbot). "
        <> "The human is sending you a direct message. "
        <> "Think about what they need and compose a clear, specific message to S. "
        <> "Be brief and actionable."
      let user_prompt = "Human says: " <> args
      notify_info(ctx, "[AUTONOMIC] A thinking about human message...")
      promise.await(
        call_monitor(ctx, user_prompt, system_prompt),
        fn(result) {
          case result {
            Ok(response) -> {
              let message = "[A-agentbot] " <> response
              pi_send_message(pi, "autonomic-wakeup", message, "persistent")
              notify_info(ctx, "[AUTONOMIC] wake-up sent")
              promise.resolve(Ok("A processed the message and sent to S."))
            }
            Error(e) -> {
              notify_info(ctx, "[AUTONOMIC] <ERROR> call_monitor: " <> e)
              promise.resolve(Error("A failed to process: " <> e))
            }
          }
        },
      )
    }
  }
}
