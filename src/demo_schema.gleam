// demo_schema.gleam — Test proper JSON Schema generation for Pi tool parameters
//
// The bug: params_to_js generates { "title": { type: "string" } }
// which is NOT valid JSON Schema. LM Studio's Qwen3-4b rejects it with:
//   "invalid_union_discriminator: Expected 'object'"
//
// The fix: generate proper JSON Schema:
//   { "type": "object", "properties": { "title": { "type": "string" } }, "required": ["title"] }

import gleam/io
import gleam/list
import gleam/string

// --- Types ---

pub type PiParam {
  PiParam(name: String, param_type: String, required: Bool)
}

// --- Helpers ---

pub fn string_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "string", required: True)
}

pub fn opt_string_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "string", required: False)
}

pub fn number_param(name: String) -> PiParam {
  PiParam(name: name, param_type: "number", required: True)
}

// --- OLD (broken) params_to_js ---

pub fn params_to_js_old(params: List(PiParam)) -> String {
  case params {
    [] -> "{}"
    _ -> {
      let fields =
        params
        |> list.map(fn(p) {
          let base = case p.param_type {
            "string" -> "{ type: \"string\""
            "number" -> "{ type: \"number\""
            "boolean" -> "{ type: \"boolean\""
            _ -> "{ type: \"" <> p.param_type <> "\""
          }
          let closing = case p.required {
            True -> " }"
            False -> ", optional: true }"
          }
          "\"" <> p.name <> "\": " <> base <> closing
        })
        |> string.join(", ")
      "{ " <> fields <> " }"
    }
  }
}

// --- NEW (fixed) params_to_js ---

pub fn params_to_js_new(params: List(PiParam)) -> String {
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

// --- Demo main ---

pub fn main() {
  let test_cases = [
    #("Empty params (no-argument tool)", []),
    #("Single required string param", [string_param("title")]),
    #("Single optional string param", [opt_string_param("status")]),
    #("Mixed required + optional", [string_param("title"), opt_string_param("description")]),
    #("Multiple required params", [string_param("title"), string_param("description"), string_param("severity")]),
    #("Three params with optional", [string_param("message"), opt_string_param("review_id")]),
  ]

  list.each(test_cases, fn(tc) {
    let #(label, params) = tc
    io.println("=== " <> label <> " ===")
    io.println("")
    io.println("OLD (broken):")
    io.println(params_to_js_old(params))
    io.println("")
    io.println("NEW (fixed):")
    io.println(params_to_js_new(params))
    io.println("")
  })
}
