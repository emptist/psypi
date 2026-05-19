import gleam/javascript/promise
import gleam/string
import pi_extension.{
  ctx_is_idle, ctx_has_pending_messages, ctx_get_entries_json,
  ctx_get_context_usage_json, notify_info, notify_error,
  pi_send_message, call_monitor,
}

pub fn on_agent_end(
  ctx: a,
  pi: b,
) -> promise.Promise(Result(Nil, String)) {
  case ctx_is_idle(ctx) {
    False -> {
      notify_info(ctx, "[AUTONOMIC] ctx.isIdle()=false, skipping")
      promise.resolve(Ok(Nil))
    }
    True -> {
      case ctx_has_pending_messages(ctx) {
        True -> {
          notify_info(ctx, "[AUTONOMIC] pending messages, skipping")
          promise.resolve(Ok(Nil))
        }
        False -> {
          notify_info(ctx, "[AUTONOMIC] idle + no pending, calling LLM...")
          let entries_json = ctx_get_entries_json(ctx)
          let usage_json = ctx_get_context_usage_json(ctx)
          compose_and_send(ctx, pi, entries_json, usage_json)
        }
      }
    }
  }
}

fn compose_and_send(
  ctx: a,
  pi: b,
  entries_json: String,
  usage_json: String,
) -> promise.Promise(Result(Nil, String)) {
  let system_prompt = "You are the Autonomic Worker. The Somatic Worker just went idle. Your job: review the context and decide if anything needs attention. If something needs attention, compose a brief natural message for the S-worker. If nothing needs attention, respond with ONLY: SKIP"

  let user_prompt = "Recent session entries:\n"
    <> truncate(entries_json, 3000)
    <> "\n\nContext usage:\n"
    <> usage_json
    <> "\n\nDecide: does the S-worker need to be woken up? If yes, write the wake-up message. If no, respond SKIP."

  promise.map(
    call_monitor(ctx, user_prompt, system_prompt),
    fn(result) {
      case result {
        Ok("SKIP") -> {
          notify_info(ctx, "[AUTONOMIC] LLM decided: nothing needs attention")
          Ok(Nil)
        }
        Ok("") -> {
          let msg = "[AUTONOMIC] callMonitor returned empty — LLM produced no output"
          notify_error(ctx, msg)
          pi_send_message(pi, "autonomic-wakeup", msg, "persistent")
          Ok(Nil)
        }
        Ok(msg) -> {
          notify_info(ctx, "[AUTONOMIC] sending wake-up to S-worker...")
          pi_send_message(pi, "autonomic-wakeup", msg, "persistent")
          notify_info(ctx, "[AUTONOMIC] wake-up sent")
          Ok(Nil)
        }
        Error(e) -> {
          let msg = "[AUTONOMIC] callMonitor failed: " <> e
          notify_error(ctx, msg)
          pi_send_message(pi, "autonomic-wakeup", msg, "persistent")
          Ok(Nil)
        }
      }
    },
  )
}

fn truncate(s: String, max: Int) -> String {
  case string.length(s) > max {
    True -> string.slice(s, 0, max) <> "..."
    False -> s
  }
}
