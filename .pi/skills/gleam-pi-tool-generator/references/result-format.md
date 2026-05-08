# ResultFormat Reference

## Type Definition

```gleam
pub type ResultFormat {
  RawJson
  Template(String)
  CustomJs(String)
}
```

## Variants

### RawJson
Returns `JSON.stringify(r.value)` — the result as JSON.

```gleam
result_format: raw_json()
// Generates: JSON.stringify(r.value)
```

Use when: the Gleam function returns a complex type (record, list) that should be serialized.

### Template(String)
Returns a template string with `${r.value}` interpolation.

```gleam
result_format: template("Task: ${r.value}")
// Generates: `Task: ${r.value}`
```

Use when: the result is a simple string/number and you want a human-readable message.

### CustomJs(String)
Returns an arbitrary JS expression that produces the text.

```gleam
result_format: custom_js("r.value.map(t => t.title).join(', ')")
// Generates: r.value.map(t => t.title).join(', ')
```

Use when: you need to transform the result in JS before displaying.

## Helpers

```gleam
raw_json()              // RawJson
template("Task: ${r.id}")  // Template("Task: ${r.id}")
custom_js("r.value.join(', ')")  // CustomJs("r.value.join(', ')")
```

## Examples

```gleam
// Identity tool — returns a record, serialize as JSON
result_format: raw_json()

// Task add — returns an ID string, show friendly message
result_format: template("Task: ${r.value}")

// Task list — returns a list of records, serialize as JSON
result_format: raw_json()

// Custom — format a list of titles
result_format: custom_js("r.value.map(t => t.title).join('\\n')")
```
