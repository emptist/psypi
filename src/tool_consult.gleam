import gleam/javascript/promise
import pi_extension.{call_monitor, notify_info}

pub fn on_consult(
  question: String,
  ctx: a,
) -> promise.Promise(Result(String, String)) {
  let system_prompt = "You are Monitor, a senior technical advisor. Provide concise, actionable advice. Consider: safety, quality, architecture, trade-offs."
  let user_prompt = case question == "" {
    True -> "What should I consider?"
    False -> question
  }
  promise.map(
    call_monitor(ctx, user_prompt, system_prompt),
    fn(result) {
      case result {
        Ok(response) -> {
          let marked = "[Autonomic] " <> response
          notify_info(ctx, marked)
          Ok(marked)
        }
        Error(e) -> Error("Autonomic error: " <> e)
      }
    },
  )
}
