// pi_command_gen.gleam — PiCommandReg → JavaScript source text
//
// Converts PiCommandReg values into pi.registerCommand({...}) JS blocks.
//
// ⚠️  AI AGENT RULES FOR THIS FILE:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. NEVER hand-write JS logic inside Gleam strings. If you need JS
//    behavior that doesn't exist yet, add a Gleam helper function that
//    EMITS the JS text — just like result_to_js() and hook_import_line()
//    do. The Gleam code is a TEXT GENERATOR, not a place to embed raw JS.
//
// 2. NEVER hand-write SQL inside Gleam strings. If you need DB access,
//    add the query to a Gleam module (e.g. event_hooks.gleam) and
//    import/call it from the generated JS.
//
// 3. Gleam string escaping is NOT JavaScript escaping. In Gleam
//    double-quoted strings: \" for literal ", \\ for literal \.
//    Single quotes (') need NO escaping in Gleam strings.
//
// 4. Every list element in the output MUST end with a comma. Missing
//    commas cause cryptic parse errors on the NEXT line.
//
// 5. When in doubt: look at how the existing functions handle the same
//    pattern and copy that structure exactly.

import gleam/list
import gleam/string
import pi_tool_call.{
  type FnArg, type PiCommandReg, type ResultFormat, FromParam, JsLiteral, RawJson,
  Template, CustomJs,
}

// -------------------------------------------------------------------
// Internal helpers
// -------------------------------------------------------------------

fn result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(r.value)"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
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
        JsLiteral(v) -> v
        FromParam(e) -> e
      }
    })
    |> string.join(", ")
  module <> "_" <> fn_name <> "(" <> args_js <> ")"
}

// -------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------

/// Generate the complete pi.registerCommand({...}) block as JS text
pub fn command_to_js(cmd: PiCommandReg) -> String {
  case cmd {
    pi_tool_call.PiRawCommand(name:, description:, handler_body:) -> {
      [
        "  // " <> description,
        "  pi.registerCommand(\"" <> name <> "\", {",
        "    description: \"" <> description <> "\",",
        "    handler: async (args, ctx) => {",
        handler_body,
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }

    pi_tool_call.PiCommandReg(name:, description:, module:, fn_name:, args:, result_format:) -> {
      let import_line = hook_import_line(module, fn_name)
      let call = hook_call_expr(module, fn_name, args)
      let result_js = result_to_js(result_format)
      [
        "  // " <> description,
        "  pi.registerCommand(\"" <> name <> "\", {",
        "    description: \"" <> description <> "\",",
        "    handler: async (args, ctx) => {",
        "      try {",
        "        " <> import_line,
        "        const result = await " <> call <> ";",
        "        const r = unwrapGleamResult(result);",
        "        return r.ok ? { content: [{ type: \"text\", text: " <> result_js <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
        "      } catch(e) {",
        "        return { content: [{ type: \"text\", text: `Error: ${e.message || String(e)}` }] };",
        "      }",
        "    }",
        "  });",
        "",
      ]
      |> list.map(fn(s) { s <> "\n" })
      |> string.concat
    }
  }
}
