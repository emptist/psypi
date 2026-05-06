import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option}
import gleam/list
import gleam/string
import psypi_cli/db

pub type Memory {
  Memory(
    id: String,
    content: String,
    tags: List(String),
    source: String,
    agent_id: String,
    importance: Int,
    created_at: String,
  )
}

pub type MemoryError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_memory_error(e: db.DbError) -> MemoryError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Decoder for Memory
fn memory_decoder() -> decode.Decoder(Memory) {
  use id <- decode.field("id", decode.string)
  use content <- decode.field("content", decode.string)
  use tags <- decode.field("tags", decode.list(decode.string))
  use source <- decode.field("source", decode.string)
  use agent_id <- decode.field("agent_id", decode.string)
  use importance <- decode.field("importance", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Memory(id:, content:, tags:, source:, agent_id:, importance:, created_at:))
}

/// Save memory to database
pub fn save(
  content: String,
  tags: List(String),
  source: String,
  importance: Int,
  agent_id: String,
) -> promise.Promise(Result(String, MemoryError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO memory (content, tags, source, importance, agent_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
    "
    let params = [
      dynamic.string(content),
      dynamic.string(string.join(tags, ",")), // TODO: handle array properly
      dynamic.string(source),
      dynamic.int(importance),
      dynamic.string(agent_id),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_memory_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(QueryError("No ID returned"))
            [row, ..] -> {
              case decode.run(row, memory_decoder()) {
                Ok(mem) -> Ok(mem.id)
                Error(_) -> Error(DecodeError("Failed to decode memory"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_memory_error)
}

/// Search memories by keyword
pub fn search(
  search_term: String,
  limit: Int,
) -> promise.Promise(Result(List(Memory), MemoryError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT * FROM memory 
      WHERE content ILIKE $1 OR tags::text ILIKE $1
      ORDER BY importance DESC, created_at DESC
      LIMIT $2
    "
    let params = [
      dynamic.string("%" <> search_term <> "%"),
      dynamic.int(limit),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_memory_error(e))
        Ok(result) -> {
          let memories = result.rows
            |> list.map(fn(row) {
              case decode.run(row, memory_decoder()) {
                Ok(mem) -> [mem]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(memories)
        }
      }
    })
  }, db_error_to_memory_error)
}
