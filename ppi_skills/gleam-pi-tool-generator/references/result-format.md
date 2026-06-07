# ResultFormat Reference

## Type Definition

```gleam
pub type ResultFormat {
  RawJson
  Template(String)
}
```

Note: `CustomJs(String)` has been **DELETED**. There is no escape hatch for arbitrary JS expressions.

## Variants

### RawJson
Returns `JSON.stringify(gleamValueToJson(r.value))` — the result as JSON.

```gleam
result_format: raw_json()
// Generates: JSON.stringify(gleamValueToJson(r.value))
```

Use when: the Gleam function returns a complex type (record, list) that should be serialized.

### Template(String)
Returns a template string with `${...}` interpolation.

```gleam
result_format: template("Task: ${r.value}")
// Generates: `Task: ${r.value}`
```

Use when: the result is a simple string/number and you want a human-readable message.

## Helpers

```gleam
raw_json()                      // RawJson
template("Task: ${r.id}")       // Template("Task: ${r.id}")
```

## Examples

```gleam
// Identity tool — returns a record, serialize as JSON
result_format: raw_json()

// Task add — returns an ID string, show friendly message
result_format: template("Task added: ${r.value}")

// Task list — returns a list of records, serialize as JSON
result_format: raw_json()

// Finding add — returns a confirmation string
result_format: template("Finding added: ${r.value}")
```

## DELETED (Do NOT Reintroduce)

| Old | Why deleted |
|-----|-------------|
| `CustomJs(String)` | Allowed arbitrary JS expressions as result formatting |
| `custom_js("r.value.map(t => t.title).join(', ')")` | Use `raw_json()` or `template()` instead |
