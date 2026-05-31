import event_hooks
import gleam/javascript/promise
import gleam/string

pub fn on_agent_start() -> promise.Promise(Result(Nil, String)) {
  promise.map(event_hooks.record_trigger("agent_start"), fn(r) {
    case r {
      Ok(_) -> Ok(Nil)
      Error(e) -> Error(string.inspect(e))
    }
  })
}
