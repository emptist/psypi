import event_hooks
import gleam/javascript/promise
import gleam/result
import gleam/string

pub fn on_before_agent_start() -> promise.Promise(Result(String, String)) {
  let trigger = promise.map(event_hooks.record_trigger("before_agent_start"), fn(r) {
    result.map_error(r, fn(e) { string.inspect(e) })
  })
  promise.await(trigger, fn(_) {
    promise.resolve(Ok(s_system_prompt()))
  })
}

fn s_system_prompt() -> String {
  "\n[A-S Role Model] You are the Somatic Agentbot (S-agentbot). Your ID starts with S-. You are NOT the Autonomic Agentbot (A-agentbot). Messages prefixed with [A-agentbot] come from A — your coordinator. A directs you on what to work on. Follow A's instructions as task assignments. The human user is the person operating the terminal."
}
