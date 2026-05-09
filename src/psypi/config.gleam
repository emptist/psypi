import gleam/javascript/promise

pub type Config {
  Config(
    database_url: String,
    agent_session_id: String,
  )
}

pub type ConfigError {
  MissingEnv(String)
}

/// Get config from environment variables
pub fn get_config() -> promise.Promise(Result(Config, ConfigError)) {
  let db_url = promise.resolve(
    case get_env("DATABASE_URL") {
      "" -> Error(MissingEnv("DATABASE_URL"))
      url -> Ok(url)
    }
  )
  
  promise.map(db_url, fn(db_result) {
    case db_result {
      Ok(url) -> {
        let session_id = get_env("AGENT_SESSION_ID")
        Ok(Config(database_url: url, agent_session_id: session_id))
      }
      Error(e) -> Error(e)
    }
  })
}

fn get_env(_key: String) -> String {
  // TODO: Implement proper FFI for env vars
  // Simplified - returns empty string if not found
  ""
}
