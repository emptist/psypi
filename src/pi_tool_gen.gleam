// pi_tool_gen.gleam — PiToolCall → JavaScript source text
//
// Converts PiToolCall values into pi.registerTool({...}) JS blocks.
//
// ⚠️  AI AGENT RULES FOR THIS FILE:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 1. NEVER hand-write JS logic inside Gleam strings. If you need JS
//    behavior that doesn't exist yet, add a Gleam helper function that
//    EMITS the JS text — just like params_to_js() and args_to_js() do.
//    The Gleam code is a TEXT GENERATOR, not a place to embed raw JS.
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
  type FnArg, type PiParam, type PiToolCall, type ResultFormat, CustomJs,
  FromParam, JsLiteral, RawJson, Template,
}

/// Generate the TypeBox parameters schema as JS text
pub fn params_to_js(params: List(PiParam)) -> String {
  case params {
    [] -> "{ \"type\": \"object\", \"properties\": {} }"
    _ -> {
      let properties =
        params
        |> list.map(fn(p) {
          let base = case p.param_type {
            "string" -> "{ \"type\": \"string\""
            "number" -> "{ \"type\": \"number\""
            "boolean" -> "{ \"type\": \"boolean\""
            _ -> "{ \"type\": \"" <> p.param_type <> "\""
          }
          "\"" <> p.name <> "\": " <> base <> " }"
        })
        |> string.join(",\n      ")

      let required =
        params
        |> list.filter(fn(p) { p.required })
        |> list.map(fn(p) { "\"" <> p.name <> "\"" })
        |> string.join(", ")

      "{ \"type\": \"object\",\n    \"properties\": {\n      " <> properties <> "\n    },\n    \"required\": [" <> required <> "]\n  }"
    }
  }
}

/// Generate the function call arguments as JS text
pub fn args_to_js(args: List(FnArg)) -> String {
  args
  |> list.map(fn(a) {
    case a {
      JsLiteral(v) -> v
      FromParam(e) -> e
    }
  })
  |> string.join(", ")
}

/// Generate the result formatting JS text
pub fn result_to_js(format: ResultFormat) -> String {
  case format {
    RawJson -> "JSON.stringify(r.value)"
    Template(tpl) -> "`" <> tpl <> "`"
    CustomJs(expr) -> expr
  }
}

/// Generate the complete pi.registerTool({...}) block as JS text
pub fn to_js_text(tool: PiToolCall) -> String {
  let params_js = params_to_js(tool.params)
  let args_js = args_to_js(tool.args)
  let call_expr = tool.module <> "_" <> tool.fn_name <> "(" <> args_js <> ")"
  let result_js = result_to_js(tool.result_format)
  let name = tool.name

  [
    "  // " <> tool.description,
    "  pi.registerTool({",
    "    name: \"" <> name <> "\",",
    "    description: \"" <> tool.description <> "\",",
    "    parameters: " <> params_js <> ",",
    "    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {",
    "      try {",
    "        const result = await " <> call_expr <> ";",
    "        const r = unwrapGleamResult(result);",
    "        if (!r.ok) {",
    "          pi_extension_notify_error(ctx, 'Tool " <> name <> " error: ' + r.error);",
    "        }",
    "        return r.ok ? { content: [{ type: \"text\", text: "
      <> result_js
      <> " }] } : { content: [{ type: \"text\", text: `Error: ${r.error}` }] };",
    "      } catch(e) {",
    "        pi_extension_notify_error(ctx, 'Tool " <> name <> " exception: ' + (e.message || String(e)));",
    "        return { content: [{ type: \"text\", text: `Error: ${e.message || String(e)}` }] };",
    "      }",
    "    }",
    "  });",
    "",
  ]
  |> list.map(fn(s) { s <> "\n" })
  |> string.concat
}

/// Generate the import statement for this tool's Gleam module
pub fn to_import_line(tool: PiToolCall) -> String {
  let base = "./build/dev/javascript/psypi"
  let alias = tool.module <> "_" <> tool.fn_name
  "import { " <> tool.fn_name <> " as " <> alias <> " } from \"" <> base <> "/" <> tool.module <> ".mjs\";"
}
