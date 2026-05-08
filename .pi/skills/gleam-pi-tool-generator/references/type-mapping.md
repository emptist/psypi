# Gleam Types → JS Objects

When `gleam build` compiles Gleam to JavaScript, custom types become JS classes/objects.
This is how `PiToolCall` values exist at runtime for the generator to use.

## PiToolCall

**Gleam:**
```gleam
pub type PiToolCall {
  PiToolCall(name: String, description: String, params: List(PiParam),
             module: String, fn_name: String, args: List(FnArg),
             result_format: ResultFormat)
}
```

**Compiled JS:**
```javascript
class PiToolCall extends CustomType {
  constructor(name, description, params, module, fn_name, args, result_format) {
    super();
    this.name = name;
    this.description = description;
    this.params = params;
    this.module = module;
    this.fn_name = fn_name;
    this.args = args;
    this.result_format = result_format;
  }
}
```

## ResultFormat

**Gleam:**
```gleam
pub type ResultFormat {
  RawJson
  Template(String)
  CustomJs(String)
}
```

**Compiled JS:**
```javascript
class RawJson extends CustomType {}
class Template extends CustomType { constructor($0) { this[0] = $0; } }
class CustomJs extends CustomType { constructor($0) { this[0] = $0; } }
```

## FnArg

**Gleam:**
```gleam
pub type FnArg {
  JsLiteral(String)
  FromParam(String)
}
```

**Compiled JS:**
```javascript
class JsLiteral extends CustomType { constructor($0) { this[0] = $0; } }
class FromParam extends CustomType { constructor($0) { this[0] = $0; } }
```

## PiParam

**Gleam:**
```gleam
pub type PiParam {
  PiParam(name: String, param_type: String, required: Bool)
}
```

**Compiled JS:**
```javascript
class PiParam extends CustomType {
  constructor(name, param_type, required) {
    super();
    this.name = name;
    this.param_type = param_type;
    this.required = required;
  }
}
```

## How the Generator Uses These

The generator (after `gleam build`) calls:
```javascript
// Import compiled values
const { my_id_tool } = await import("...agent_identity.mjs");
const { to_js_text } = await import("...pi_tool_call.mjs");

// Get PiToolCall object
const tool = my_id_tool();
// tool instanceof PiToolCall → true
// tool.name → "psypi-my-id"

// Convert to JS text string
const jsCode = to_js_text(tool);
// → "  pi.registerTool({ name: \"psypi-my-id\", ... });\n\n"
```

The `to_js_text` function pattern-matches on the Gleam object's constructor:
```javascript
function result_to_js_text(format) {
  if (format instanceof RawJson) return "JSON.stringify(r.value)";
  if (format instanceof Template) return `\`${format[0]}\``;
  if (format instanceof CustomJs) return format[0];
}
```

## Key Insight

The Gleam compiler generates these JS classes. The generator doesn't need to know
the internal structure — it just calls `to_js_text(tool)` which handles the conversion.
All type safety is enforced at Gleam compile time, not at JS runtime.
