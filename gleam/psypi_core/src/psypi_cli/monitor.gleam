import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option, None, Some}
import psypi_cli/db

pub type MonitorModel {
  MonitorModel(
    provider: String,
    model: Option(String),
  )
}

pub type MonitorError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn db_error_to_monitor_error(e: db.DbError) -> MonitorError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn monitor_model_decoder() -> decode.Decoder(MonitorModel) {
  use provider <- decode.field("provider", decode.string)
  use model <- decode.field("model", decode.optional(decode.string))
  decode.success(MonitorModel(provider:, model:))
}

/// Get the current Monitor AI model from database
pub fn get_model() -> promise.Promise(Result(Option(MonitorModel), MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT provider, model 
      FROM provider_api_keys 
      WHERE status = 'in_use' 
      LIMIT 1
    "
    let params: List(dynamic.Dynamic) = []

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Ok(None)
            [row, ..] -> {
              case decode.run(row, monitor_model_decoder()) {
                Ok(m) -> Ok(Some(m))
                Error(_) -> Error(DecodeError("Failed to decode monitor model"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Set the Monitor AI model in database
pub fn set_model(
  provider: String,
  model: Option(String),
) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    // First, reset all to 'not_used'
    let reset_sql = "UPDATE provider_api_keys SET status = 'not_used'"
    let reset_params: List(dynamic.Dynamic) = []

    promise.await(db.query(conn, reset_sql, reset_params), fn(reset_result) {
      case reset_result {
        Error(e) -> promise.resolve(Error(db_error_to_monitor_error(e)))
        Ok(_) -> {
          // Then set the specified provider to 'in_use'
          let update_sql = case model {
            Some(_) -> 
              "UPDATE provider_api_keys SET status = 'in_use', model = $2 WHERE provider = $1"
            None ->
              "UPDATE provider_api_keys SET status = 'in_use' WHERE provider = $1"
          }
          let update_params = case model {
            Some(m) -> [dynamic.string(provider), dynamic.string(m)]
            None -> [dynamic.string(provider)]
          }

          promise.await(db.query(conn, update_sql, update_params), fn(update_result) {
            case update_result {
              Error(e) -> promise.resolve(Error(db_error_to_monitor_error(e)))
              Ok(_) -> promise.resolve(Ok(Nil))
            }
          })
        }
      }
    })
  }, db_error_to_monitor_error)
}
