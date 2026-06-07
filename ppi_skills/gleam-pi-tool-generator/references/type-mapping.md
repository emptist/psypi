# Gleam Types → JS Objects

When `gleam build` compiles Gleam to JavaScript, custom types become JS classes/objects.
This is how `PiToolCall` values exist at runtime for the generator to use.

## PiToolCall

**Gleam:**
```gleam
pub type PiToolCall {
  PiToolCall(name: String, description: String, params: List(PiParam),
             module: String, fn_name: String, args: List(FnArgument),
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
}
```

**Compiled JS:**
```javascript
class RawJson extends CustomType {}
class Template extends CustomType { constructor($0) { this[0] = $0; } }
```

Note: `CustomJs` has been deleted.

## FnArgument

**Gleam:**
```gleam
pub type FnArgument {
  FromParam(ParamSrc)
  Ctx
  Pi
  StringConst(String)
  IntConst(Int)
  NullConst
}
```

**Compiled JS:**
```javascript
class FromParam extends CustomType { constructor($0) { this[0] = $0; } }
class Ctx extends CustomType {}
class Pi extends CustomType {}
class StringConst extends CustomType { constructor($0) { this[0] = $0; } }
class IntConst extends CustomType { constructor($0) { this[0] = $0; } }
class NullConst extends CustomType {}
```

## ParamSrc

**Gleam:**
```gleam
pub type ParamSrc {
  ParamField(name: String, default: Option(String))
  OptionalParamField(name: String)
  IntParamField(name: String, default: Int)
  EventField(name: String, default: Option(String))
  EventJsonField(name: String)
  EventFilePath
  CtxField(name: String)
  ArgsField
}
```

**Compiled JS:**
```javascript
class ParamField extends CustomType { constructor(name, default_) { this.name = name; this.default = default_; } }
class OptionalParamField extends CustomType { constructor(name) { this.name = name; } }
class IntParamField extends CustomType { constructor(name, default_) { this.name = name; this.default = default_; } }
class EventField extends CustomType { constructor(name, default_) { this.name = name; this.default = default_; } }
class EventJsonField extends CustomType { constructor(name) { this.name = name; } }
class EventFilePath extends CustomType {}
class CtxField extends CustomType { constructor(name) { this.name = name; } }
class ArgsField extends CustomType {}
```

## HookGuard

**Gleam:**
```gleam
pub type HookGuard {
  CtxFieldExists(String)
  EventFieldExists(String)
  NoGuard
}
```

**Compiled JS:**
```javascript
class CtxFieldExists extends CustomType { constructor($0) { this[0] = $0; } }
class EventFieldExists extends CustomType { constructor($0) { this[0] = $0; } }
class NoGuard extends CustomType {}
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
const { task_add_tool } = await import("...task.mjs");
const { to_js_text } = await import("...pi_tool_call.mjs");

// Get PiToolCall object
const tool = task_add_tool();
// tool instanceof PiToolCall → true
// tool.name → "psypi-task-add"

// Convert to JS text string
const jsCode = to_js_text(tool);
// → "  pi.registerTool({ name: \"psypi-task-add\", ... });\n\n"
```

The `to_js_text` function pattern-matches on the Gleam object's constructor:
```javascript
function result_to_js(format) {
  if (format instanceof RawJson) return "JSON.stringify(gleamValueToJson(r.value))";
  if (format instanceof Template) return "`" + format[0] + "`";
}
```

## Key Insight

The Gleam compiler generates these JS classes. The generator doesn't need to know
the internal structure — it just calls `to_js_text(tool)` which handles the conversion.
All type safety is enforced at Gleam compile time, not at JS runtime.
