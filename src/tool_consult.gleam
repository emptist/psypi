import gleam/javascript/promise
import pi_extension.{notify_info}

pub fn on_consult(
  question: String,
  ctx: a,
) -> promise.Promise(Result(String, String)) {
  let user_question = case question == "" {
    True -> "What should I consider?"
    False -> question
  }
  notify_info(ctx, "[AUTONOMIC] Consult: " <> user_question)
  // Note: pi_send_message signature is (pi, customType, content, display)
  // but here ctx is passed as first arg since the Gleam FFI uses (ctx, ...)
  // We use a simple approach: notify and return the question for the S-worker
  promise.resolve(Ok("[Autonomic] Consult request: " <> user_question <> "\n\nThe S-worker should address this in its next turn."))
}
