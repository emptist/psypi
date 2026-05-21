// pi_hook_gen.gleam — PiEventHook → JavaScript source text
//
// Converts PiEventHook values into pi.on('event', ...) JS blocks.

import gleam/list
import gleam/string
import gleam/option.{Some, None}
import pi_tool_call.{
  type FnArg, type HookSuccessAction, type PiEventHook,
  NotifyError, SetStatus, SilentSuccess, NotifySuccess,
}

// -------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------

fn success_action_to_js(action: HookSuccessAction) -> String {
  case action {
    SilentSuccess -> ""
    NotifySuccess(msg) -> "ctx.ui.notify('" <> msg <> "', 'info');"
    SetStatus(key, text) ->
      "ctx.ui.setStatus('" <> key <> "', '" <> text <> "');"
  }
}

fn hook_import_line(module: String, fn_name: String) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = module <> "_" <> fn_name
  "const " <> alias <> " = (await import('" <> base <> "/" <> module <> ".mjs'))." <> fn_name <> ";"
}

fn hook_call_expr(module: String, fn_name: String, args: List(FnArg)) -> String {
  let args_js =
    args
    |> list.map(fn(a) {
      case a {
        pi_tool_call.JsLiteral(v) -> v
        pi_tool_call.FromParam(e) -> e
      }
    })
    |> string.join(", ")
  module <> "_" <> fn_name <> "(" <> args_js <> ")"
}

// -------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------

/// Generate the complete pi.on('event', ...) block as JS text
pub fn event_hook_to_js(hook: PiEventHook) -> String {
  case hook {
    pi_tool_call.PiRawHook(event_name:, handler_body:) -> {
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        handler_body,
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiEventHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      guard:,
      on_success:,
      on_error:,
    ) -> {
      let import_line = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)

      let guard_prefix = case guard {
        Some(g) -> "    if (" <> g <> ") {\n"
        None -> ""
      }
      let guard_suffix = case guard {
        Some(_) -> "    }\n"
        None -> ""
      }
      let success_js = success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          "      ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
          <> "      pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
      }
      [
        "  // Event hook: " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        guard_prefix,
        "      " <> import_line,
        "      const result = await " <> call <> ";",
        "      const r = unwrapGleamResult(result);",
        "      if (r.ok) { " <> success_js <> " }",
        "      else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
        "      await record_trigger('" <> event_name <> "');",
        guard_suffix,
        "    } catch(e) {",
        error_catch,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiDebouncedHook(
      event_name:,
      module:,
      fn_name:,
      args:,
      debounce_ms_module:,
      debounce_ms_fn:,
      guard: _,
      on_success:,
      on_error:,
    ) -> {
      let debounce_import =
        hook_import_line(debounce_ms_module, debounce_ms_fn)
      let debounce_call =
        debounce_ms_module <> "_" <> debounce_ms_fn <> "()"
      let hook_import_line_ = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let success_js = success_action_to_js(on_success)
      let error_catch = case on_error {
        NotifyError ->
          "        ctx.ui.notify('Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
          <> "        pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " error: ' + (e.message || String(e)), 'error');\n"
      }
      [
        "  // Event hook (debounced): " <> event_name,
        "  pi.on('" <> event_name <> "', async (event, ctx) => {",
        "    try {",
        "      // Phase 1: Check if S is actually idle",
        "      const idle = ctx.isIdle();",
        "      ctx.ui.notify('[AUTONOMIC] isIdle=' + idle, 'info');",
        "      if (!idle) { return; }",
        "      " <> debounce_import,
        "      const debounceResult = await " <> debounce_call <> ";",
        "      const dr = unwrapGleamResult(debounceResult);",
        "      if (!dr.ok) { ctx.ui.notify('Hook " <> event_name <> " <ERROR> debounce config: ' + dr.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " <ERROR> debounce config: ' + dr.error, 'error'); return; }",
        "      const debounceMs = dr.value;",
        "      setTimeout(async () => {",
        "        try {",
        "          ctx.ui.notify('[AUTONOMIC] setTimeout callback fired for " <> event_name <> "', 'info');",
        "          " <> hook_import_line_,
        "          const result = await " <> call <> ";",
        "          const r = unwrapGleamResult(result);",
        "          if (r.ok) { " <> success_js <> " }",
        "          else { ctx.ui.notify('Hook " <> event_name <> " failed: ' + r.error, 'error'); pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " failed: ' + r.error, 'error'); }",
        "        } catch(e) {",
        error_catch,
        "        }",
        "      }, debounceMs);",
        "    } catch(e) {",
        "      ctx.ui.notify('Hook " <> event_name <> " debounce error: ' + (e.message || String(e)), 'error');",
        "      pi_extension_pi_send_message(pi, 'hook-error', 'Hook " <> event_name <> " debounce error: ' + (e.message || String(e)), 'error');",
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }
  }
}
