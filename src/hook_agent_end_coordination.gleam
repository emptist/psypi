// Agent end coordination hook — A-worker wake-up logic.
// The JS handler body is stored as a separate asset for maintainability.
// See: js_assets/agent_end_coordination.js

import simplifile

pub fn handler_body() -> String {
  case simplifile.read("src/js_assets/agent_end_coordination.js") {
    Ok(content) -> content
    Error(_) -> "// agent_end_coordination: failed to load JS asset\n"
  }
}
