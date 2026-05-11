import gleam/string
import gleam/list

pub type LogLevel {
  Debug
  Info
  Warn
  Error
}

fn level_to_string(level: LogLevel) -> String {
  case level {
    Debug -> "DEBUG"
    Info -> "INFO"
    Warn -> "WARN"
    Error -> "ERROR"
  }
}

pub fn format_log(level: LogLevel, message: String, context: List(#(String, String))) -> String {
  let ctx_str = context
    |> list.map(fn(p) { p.0 <> "=" <> p.1 })
    |> string.join(" ")
  let level_str = level_to_string(level)
  "[" <> level_str <> "] " <> message <> " " <> ctx_str
}

pub fn is_level_enabled(configured: LogLevel, current: LogLevel) -> Bool {
  case configured, current {
    Debug, _ -> True
    Info, Debug -> False
    Info, _ -> True
    Warn, Debug -> False
    Warn, Info -> False
    Warn, _ -> True
    Error, Error -> True
    Error, _ -> False
  }
}
