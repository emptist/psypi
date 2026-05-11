import gleam/io

/// Simple hello function
pub fn hello(name: String) -> String {
  "Hi, " <> name <> "!"
}

/// Print hello message
pub fn print_hello(name: String) -> Nil {
  io.println(hello(name))
}
