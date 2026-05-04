import gleam/io
import gleam/string

/// Simple hello function
pub fn hello(name: String) -> String {
  "Hello, " <> name <> "!"
}

/// Print hello message
pub fn print_hello(name: String) -> Nil {
  io.println(hello(name))
}
