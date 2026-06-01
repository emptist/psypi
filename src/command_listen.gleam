import gleam/javascript/promise
import gleam/string
import pi_extension.{
  call_monitor, ctx_notify, pi_send_message,
}

pub fn on_autonomic_listen(
  args: String,
  ctx: a,
  pi: b,
) -> promise.Promise(Result(String, String)) {
  case args == "" {
    True -> {
      ctx_notify(ctx, "Usage: /autonomic-listen <message>", "info")
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
      ctx_notify(ctx, "[AUTONOMIC] A thinking about human message...", "info")
      promise.await(
        call_monitor(ctx, user_prompt, system_prompt),
        fn(result) {
          case result {
            Ok(response) -> {
              let message = case string.starts_with(response, "[A-agentbot]") {
                True -> response
                False -> "[A-agentbot] " <> response
              }
              pi_send_message(pi, "autonomic-wakeup", message, "persistent", True)
              ctx_notify(ctx, "[AUTONOMIC] wake-up sent", "info")
              promise.resolve(Ok("A processed the message and sent to S."))
            }
            Error(e) -> {
              ctx_notify(ctx, "[AUTONOMIC] <ERROR> call_monitor: " <> e, "error")
              promise.resolve(Error("A failed to process: " <> e))
            }
          }
        },
      )
    }
  }
}
