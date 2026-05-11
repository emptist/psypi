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

/// Read config from environment or file (FFI placeholder)
pub fn read_config() -> promise.Promise(Result(Config, ConfigError)) {
  // Simplified - returns default config
  let default_config = Config(
    database_url: "postgresql://localhost/psypi",
    log_level: "info",
    port: 3000,
  )
  promise.resolve(Ok(default_config))
}
