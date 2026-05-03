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
  let config = node_pg.create_config(
    Some("postgres"),
    None,
    Some("localhost"),
    Some(5432),
    Some("psypi"),
  )

  let client = node_pg.new_client(config)

  promise.map(node_pg.connect(client), fn(result) {
    case result {
      Ok(_) -> Ok(Connection(client))
      Error(e) -> Error(ConnectionError(e.message))
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
