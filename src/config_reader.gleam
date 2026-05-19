import gleam/int
import gleam/javascript/promise

pub type Config {
  Config(
    database_url: String,
    log_level: String,
    port: Int,
  )
}

pub type ConfigError {
  NotFound
  ReadError(String)
}

/// Read config from environment — no defaults, no fallbacks.
/// If a required env var is missing, return NotFound.
pub fn read_config() -> promise.Promise(Result(Config, ConfigError)) {
  case get_env("DATABASE_URL") {
    Error(e) -> promise.resolve(Error(e))
    Ok(database_url) -> {
      case get_env("LOG_LEVEL") {
        Error(e) -> promise.resolve(Error(e))
        Ok(log_level) -> {
          case get_env("PORT") {
            Error(e) -> promise.resolve(Error(e))
            Ok(port_str) -> {
              case int.parse(port_str) {
                Error(_) -> promise.resolve(Error(ReadError("Invalid PORT: " <> port_str)))
                Ok(port) -> promise.resolve(Ok(Config(
                  database_url: database_url,
                  log_level: log_level,
                  port: port,
                )))
              }
            }
          }
        }
      }
    }
  }
}

@external(javascript, "./node_ffi.mjs", "get_env")
fn get_env(key: String) -> Result(String, ConfigError)
