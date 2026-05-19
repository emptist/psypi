# Workflow: Gleam JS/Erlang Interop

<required_reading>
**Read these reference files first:**
1. references/js-interop.md
2. references/syntax-basics.md
</required_reading>

<process>
## Step 1: Determine If You Need FFI

Ask: Is there a pure Gleam package that does this?
- Check https://packages.gleam.run/
- Check the core packages: `gleam_stdlib`, `gleam_time`, `gleam_http`, `gleam_erlang`, `gleam_otp`, `gleam_javascript`, `gleam_json`, `gleam_crypto`

Only use `@external` if no Gleam package exists.

## Step 2: Define External Type (for opaque values)

If the external code returns an opaque handle/value:

```gleam
pub type FileHandle
```

## Step 3: Define External Function

```gleam
// JavaScript only:
@external(javascript, "./my_module_ffi.mjs", "my_function")
pub fn my_function(input: String) -> Int

// Multi-target:
@external(javascript, "./my_module_ffi.mjs", "my_function")
@external(erlang, "my_module", "my_function")
pub fn my_function(input: String) -> Int
```

## Step 4: Design Idiomatic Gleam API

Wrap the external function with a Gleam-friendly API:

```gleam
pub fn process(input: String) -> Result(Output, Error) {
  // Convert external errors to Result
  // Validate inputs before calling external
  let external_result = my_function(input)
  case external_result {
    Ok(v) -> Ok(v)
    Error(e) -> Error(MyError(message: e))
  }
}
```

## Step 5: Write Extra Tests

External functions bypass Gleam's type checker. Write more tests than usual:

```gleam
pub fn my_function_test() {
  my_function("valid")
  |> should.be_ok

  my_function("")
  |> should.be_error
}
```

## Step 6: Build and Test

```bash
rm -rf build/ && gleam build
gleam test
```
</process>
