# Filepath — Gleam Path Utilities

## Package

```toml
# In gleam.toml dependencies:
filepath = ">= 1.0.0"
```

## API

### Join paths
```gleam
import gleam/filepath

filepath.join("/usr/local", "bin")
// -> "/usr/local/bin"

filepath.join("gleam/psypi_core", "src/agent/extension/extension.js")
// -> "gleam/psypi_core/src/agent/extension/extension.js"
```

### Split path into segments
```gleam
filepath.split("/usr/local/bin")
// -> ["/", "usr", "local", "bin"]
```

### Base name (filename)
```gleam
filepath.base_name("/usr/local/bin")
// -> "bin"
```

### Directory name
```gleam
filepath.directory_name("/usr/local/bin")
// -> "/usr/local"
```

### Extension
```gleam
filepath.extension("src/main.gleam")
// -> Ok("gleam")

filepath.extension("no_extension")
// -> Error(Nil)
```

### Strip extension
```gleam
filepath.strip_extension("src/main.gleam")
// -> "src/main"
```

### Is absolute?
```gleam
filepath.is_absolute("/usr/local/bin")
// -> True

filepath.is_absolute("usr/local/bin")
// -> False
```

### Expand `.` and `..` segments
```gleam
filepath.expand("/usr/local/../bin")
// -> Ok("/usr/bin")
```

## Related: simplifile (File I/O)

`simplifile` is Gleam's standard library for reading/writing files:
```gleam
import simplifile

// Read
case simplifile.read("path/to/file.txt") {
  Ok(content) -> // ...
  Error(e) -> // ...
}

// Write
case simplifile.write("path/to/file.txt", content) {
  Ok(_) -> // ...
  Error(e) -> // ...
}
```

## Use Case: Dynamic Path Construction

Instead of hardcoding relative paths like `"../../src/agent/extension/extension.js"`,
use `filepath.join` to compute paths from a known reference point:

```gleam
let project_root = get_project_root()  // from FFI or env var
let extension_path = filepath.join(project_root, "src/agent/extension/extension.js")
```

This works regardless of where the build output lives.
