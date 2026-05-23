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
        let session_id = case get_env("AGENT_SESSION_ID") {
          "" -> "default"
          id -> id
        }
        Ok(Config(database_url: url, agent_session_id: session_id))
      }
      Error(e) -> Error(e)
    }
  })
}

@external(javascript, "./node_ffi.mjs", "get_env")
fn get_env(key: String) -> String
