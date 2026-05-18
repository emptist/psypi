import gleam/javascript/promise
import gleam/string
import pi_extension.{
  ctx_is_idle, ctx_has_pending_messages, ctx_get_entries_json,
  ctx_get_context_usage_json, ctx_get_cwd, notify_info, notify_error,
  pi_send_message, call_monitor, read_file_sync,
}

pub fn on_agent_end(
  ctx: a,
  pi: b,
) -> promise.Promise(Result(Nil, String)) {
  case ctx_is_idle(ctx) {
    False -> {
      notify_info(ctx, "[AUTONOMIC] ctx.isIdle() = false, skipping A-worker wake-up")
      promise.resolve(Ok(Nil))
    }
    True -> {
      case ctx_has_pending_messages(ctx) {
        True -> {
          notify_info(ctx, "[AUTONOMIC] S-worker has pending messages, skipping wake-up")
          promise.resolve(Ok(Nil))
        }
        False -> {
          let entries_json = ctx_get_entries_json(ctx)
          case has_recent_wakeup(entries_json) {
            True -> {
              notify_info(ctx, "[AUTONOMIC] Recent autonomic-wakeup already in context, skipping repeat")
              promise.resolve(Ok(Nil))
            }
            False -> {
              notify_info(ctx, "[AUTONOMIC] ctx.isIdle() = true, no recent wake-up, proceeding")
              coordinate_with_s_worker(ctx, pi, entries_json)
            }
          }
        }
      }
    }
  }
}

fn has_recent_wakeup(entries_json: String) -> Bool {
  string.contains(entries_json, "autonomic-wakeup")
}

fn coordinate_with_s_worker(
  ctx: a,
  pi: b,
  entries_json: String,
) -> promise.Promise(Result(Nil, String)) {
  let brief = read_monitor_brief(ctx)
  let usage_json = ctx_get_context_usage_json(ctx)
  let token_info = extract_token_info(usage_json)
  let recent_summary = extract_recent_summary(entries_json)
  let system_prompt = build_system_prompt(token_info, brief, recent_summary)
  let user_prompt = "Somatic worker is idle. Compose a wake-up message based on the recent context."

  promise.map(
    call_monitor(ctx, user_prompt, system_prompt),
    fn(result) {
      case result {
        Ok(msg) -> {
          case msg == "" {
            True -> {
              notify_error(ctx, "[AUTONOMIC] callMonitor returned empty — LLM produced no output")
              pi_send_message(pi, "autonomic-wakeup", "[from A-worker:] Issue found! LLM produced no output", "persistent")
              Ok(Nil)
            }
            False -> {
              notify_info(ctx, "[AUTONOMIC] Sending wake-up message to S-worker...")
              pi_send_message(pi, "autonomic-wakeup", msg, "persistent")
              notify_info(ctx, "[AUTONOMIC] Wake-up message sent")
              Ok(Nil)
            }
          }
        }
        Error(e) -> {
          notify_error(ctx, "[AUTONOMIC] callMonitor failed: " <> e)
          pi_send_message(pi, "autonomic-wakeup", "[from A-worker:] LLM call failed: " <> e, "persistent")
          Ok(Nil)
        }
      }
    },
  )
}

fn read_monitor_brief(ctx: a) -> String {
  let cwd = ctx_get_cwd(ctx)
  case cwd == "" {
    True -> ""
    False -> {
      let brief_path = cwd <> "/docs/MONITOR-BRIEF.md"
      case read_file_sync(brief_path) {
        Ok(content) -> content
        Error(_) -> ""
      }
    }
  }
}

fn extract_token_info(usage_json: String) -> String {
  case string.contains(usage_json, "tokens") && string.contains(usage_json, "contextWindow") {
    True -> "Context usage available."
    False -> ""
  }
}

fn extract_recent_summary(entries_json: String) -> String {
  case string.length(entries_json) > 2000 {
    True -> string.slice(entries_json, 0, 2000) <> "..."
    False -> entries_json
  }
}

fn build_system_prompt(
  token_info: String,
  brief: String,
  recent_summary: String,
) -> String {
  let brief_section = case brief == "" {
    True -> ""
    False -> "Monitor Brief:\n" <> brief <> "\n\n"
  }
  let token_section = case token_info == "" {
    True -> ""
    False -> token_info <> "\n\n"
  }
  "You are the Autonomic Worker (Monitor). The Somatic Worker has gone idle.\n\n"
  <> token_section
  <> brief_section
  <> "Recent conversation context:\n"
  <> recent_summary
  <> "\n\nCompose a brief, natural wake-up message (1-2 sentences). Mention what needs attention based on the context. Do NOT repeat what was already said. The S-worker is smart — it will decide what to do. Prefix with [from A-worker:]."
}
