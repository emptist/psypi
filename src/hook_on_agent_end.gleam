import gleam/javascript/promise
import gleam/string
import pi_extension.{
  ctx_is_idle, ctx_has_pending_messages, ctx_get_entries_json,
  ctx_get_context_usage_json, ctx_get_cwd, notify_info,
  pi_send_message, read_file_sync,
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
          notify_info(ctx, "[AUTONOMIC] ctx.isIdle() = true, proceeding with wake-up")
          coordinate_with_s_worker(ctx, pi, entries_json)
        }
      }
    }
  }
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
  let wakeup_msg = build_wakeup_message(token_info, brief, recent_summary)
  notify_info(ctx, "[AUTONOMIC] Sending wake-up directive to S-worker...")
  pi_send_message(pi, "autonomic-wakeup", wakeup_msg, "persistent")
  notify_info(ctx, "[AUTONOMIC] Wake-up directive sent")
  promise.resolve(Ok(Nil))
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

fn build_wakeup_message(
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
  "[from A-worker:] Autonomic Worker wake-up.\n\n"
  <> "The Somatic Worker has gone idle. Review the recent context below and decide what needs attention.\n\n"
  <> token_section
  <> brief_section
  <> "Recent conversation context:\n"
  <> recent_summary
}
