import event_hooks
import gleam/javascript/promise
import gleam/result
import gleam/string
import s_db_reader

pub fn on_before_agent_start() -> promise.Promise(Result(String, String)) {
  let trigger = promise.map(event_hooks.record_trigger("before_agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
  promise.await(trigger, fn(_) {
    promise.await(s_db_reader.read_s_soul_from_db(), fn(soul_result) {
      case soul_result {
        Ok(soul_content) -> promise.resolve(Ok(soul_content))
        Error(e) ->
          promise.resolve(Ok(
            "You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. "
            <> "You are NOT the Autonomic Agentbot (A-agentbot). "
            <> "Messages from A come via pi_send_message — read and follow them. "
            <> "The human user operates the terminal.\n\n"
            <> "[SOUL LOAD FAILED: "
            <> e
            <> "]",
          ))
      }
    })
  })
}
