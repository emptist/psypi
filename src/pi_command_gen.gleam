// pi_command_gen.gleam — PiCommandReg → JavaScript source text
//
// Converts PiCommandReg values into pi.registerCommand({...}) JS blocks.

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
