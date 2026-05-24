import gleam/dynamic
import gleam/javascript/promise
import gleam/option.{None, Some}
import node_pg

pub opaque type Connection {
  Connection(client: node_pg.Client)
}

pub type DbError {
  ConnectionError(String)
  QueryError(String)
}

pub fn connect() -> promise.Promise(Result(Connection, DbError)) {
  let database_url = get_database_url()
  let config = case database_url {
    "" ->
      node_pg.create_config(
        Some("postgres"),
        None,
        Some("localhost"),
        Some(5432),
        Some("psypi"),
      )
    url -> node_pg.connection_string_config(url)
  }

  let client = node_pg.new_client(config)

  promise.await(node_pg.connect(client), fn(connect_result) {
    case connect_result {
      Error(e) -> promise.resolve(Error(ConnectionError(e.message)))
      Ok(_) -> {
        // Set app.current_project_id for RLS policies
        // Read from env var for portability; fall back to default for existing deployments
        let project_id = case get_project_id_env() {
          "" -> "0d324e68-b399-4b85-bd8a-6b1ef7b46168"
          id -> id
        }
        let set_sql = "SET app.current_project_id = $1"
        let set_params = [dynamic.string(project_id)]
        promise.map(node_pg.query(client, set_sql, set_params), fn(_) {
          Ok(Connection(client))
        })
      }
    }
  })
}

pub fn disconnect(conn: Connection) -> promise.Promise(Result(Nil, DbError)) {
  promise.map(node_pg.end(conn.client), fn(result) {
    case result {
      Ok(_) -> Ok(Nil)
      Error(e) -> Error(ConnectionError(e.message))
    }
  })
}

pub fn query(
  conn: Connection,
  sql: String,
  params: List(dynamic.Dynamic),
) -> promise.Promise(Result(node_pg.QueryResult, DbError)) {
  promise.map(node_pg.query(conn.client, sql, params), fn(result) {
    case result {
      Ok(query_result) -> Ok(query_result)
      Error(e) -> Error(QueryError(e.message))
    }
  })
}

pub fn with_connection(
  callback: fn(Connection) -> promise.Promise(Result(a, e)),
  error_mapper: fn(DbError) -> e,
) -> promise.Promise(Result(a, e)) {
  promise.await(connect(), fn(conn_result) {
    case conn_result {
      Error(e) -> promise.resolve(Error(error_mapper(e)))
      Ok(conn) -> {
        promise.await(callback(conn), fn(result) {
          let _ = disconnect(conn)
          promise.resolve(result)
        })
      }
    }
  })
}

@external(javascript, "./node_ffi.mjs", "get_project_id_env")
fn get_project_id_env() -> String

@external(javascript, "./node_ffi.mjs", "get_database_url")
fn get_database_url() -> String
