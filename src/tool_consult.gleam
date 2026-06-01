import gleam/javascript/promise
import pi_extension.{ctx_notify}

pub fn on_consult(
  question: String,
  ctx: a,
) -> promise.Promise(Result(String, String)) {
  let user_question = case question == "" {
    True -> "What should I consider?"
    False -> question
  }
  ctx_notify(ctx, "[AUTONOMIC] Consult: " <> user_question, "info")
  // Note: pi_send_message signature is (pi, customType, content, display, triggerTurn, deliverAs)
  // but here ctx is passed as first arg since the Gleam FFI uses (ctx, ...)
  // We use a simple approach: notify and return the question for the S-worker
  promise.resolve(Ok("[Autonomic] Consult request: " <> user_question <> "\n\nThe S-worker should address this in its next turn."))
}
