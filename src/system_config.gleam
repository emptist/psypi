import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import db

pub type ConfigError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn db_error_to_config_error(e: db.DbError) -> ConfigError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn config_value_decoder() -> decode.Decoder(String) {
  use value <- decode.field("value", decode.string)
  decode.success(value)
}

pub fn get(key: String) -> promise.Promise(Result(String, ConfigError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT value FROM psypi_config WHERE key = $1"
    let params = [dynamic.string(key)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_config_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, config_value_decoder()) {
                Ok(value) -> Ok(value)
                Error(_) -> Error(DecodeError("Failed to decode system_config row"))
              }
            }
            [] -> Error(NotFound("Key not found: " <> key))
          }
        }
      }
    })
  }, db_error_to_config_error)
}

pub fn get_int(
  key: String,
) -> promise.Promise(Result(Int, ConfigError)) {
  let result = get(key)
  promise.map(result, fn(r) {
    case r {
      Ok(value) -> {
        case int.parse(value) {
          Ok(int_val) -> Ok(int_val)
          Error(_) -> Error(DecodeError("Not an integer: " <> value))
        }
      }
      Error(e) -> Error(e)
    }
  })
}

pub fn get_debounce_ms() -> promise.Promise(Result(Int, ConfigError)) {
  get_int("monitor_debounce_ms")
}

pub fn set(key: String, value: String) -> promise.Promise(Result(Nil, ConfigError)) {
  db.with_connection(fn(conn) {
    let sql = "INSERT INTO psypi_config (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = now()"
    let params = [dynamic.string(key), dynamic.string(value)]

    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_config_error(e))
      }
    })
  }, db_error_to_config_error)
}
