//// Key concept definitions reader.
//// Queries the key_concept_definitions table to provide AI agents
//// with a shared vocabulary/dictionary of project concepts.

import db
import db_utils
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option
import gleam/string

pub type KeyConcept {
  KeyConcept(
    concept_key: String,
    term: String,
    definition: String,
    context: String,
    examples: String,
    anti_patterns: String,
    related_concepts: List(String),
    category: String,
  )
}

pub fn db_error_to_string(e: db.DbError) -> String {
  case e {
    db.ConnectionError(msg) -> "DB connection: " <> msg
    db.QueryError(msg) -> "DB query: " <> msg
  }
}

/// Look up a single concept by its concept_key.
/// Returns the active, non-archived definition.
pub fn lookup_concept(
  concept_key: String,
) -> promise.Promise(Result(KeyConcept, String)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "SELECT concept_key, term, definition, context, examples, anti_patterns, related_concepts, category "
        <> "FROM key_concept_definitions "
        <> "WHERE concept_key = $1 AND is_active = true AND is_archived = false"
      let params = [dynamic.string(concept_key)]
      promise.map(
        db.query(conn, sql, params),
        fn(query_result) {
          case query_result {
            Error(e) -> Error(db_error_to_string(e))
            Ok(result) ->
              case result.rows {
                [] ->
                  Error(
                    "Concept not found: " <> concept_key,
                  )
                [row, ..] ->
                  case decode.run(row, concept_decoder()) {
                    Ok(concept) -> Ok(concept)
                    Error(e) ->
                      Error(
                        "decode concept: " <> string.inspect(e),
                      )
                  }
              }
          }
        },
      )
    },
    db_error_to_string,
  )
}

/// List all active, non-archived concepts, optionally filtered by category.
pub fn list_concepts(
  category: option.Option(String),
) -> promise.Promise(Result(List(KeyConcept), String)) {
  db.with_connection(
    fn(conn) {
      case category {
        option.Some(cat) ->
          query_by_category(conn, cat)
        option.None ->
          query_all(conn)
      }
    },
    db_error_to_string,
  )
}

fn query_all(
  conn: db.Connection,
) -> promise.Promise(Result(List(KeyConcept), String)) {
  let sql =
    "SELECT concept_key, term, definition, context, examples, anti_patterns, related_concepts, category "
    <> "FROM key_concept_definitions "
    <> "WHERE is_active = true AND is_archived = false "
    <> "ORDER BY category, concept_key"
  promise.map(db.query(conn, sql, []), fn(query_result) {
    case query_result {
      Error(e) -> Error(db_error_to_string(e))
      Ok(result) ->
        db_utils.decode_rows(result.rows, concept_decoder(), fn(e) { e })
    }
  })
}

fn query_by_category(
  conn: db.Connection,
  category: String,
) -> promise.Promise(Result(List(KeyConcept), String)) {
  let sql =
    "SELECT concept_key, term, definition, context, examples, anti_patterns, related_concepts, category "
    <> "FROM key_concept_definitions "
    <> "WHERE category = $1 AND is_active = true AND is_archived = false "
    <> "ORDER BY concept_key"
  let params = [dynamic.string(category)]
  promise.map(
    db.query(conn, sql, params),
    fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_string(e))
        Ok(result) ->
          db_utils.decode_rows(result.rows, concept_decoder(), fn(e) { e })
      }
    },
  )
}

fn concept_decoder() -> decode.Decoder(KeyConcept) {
  use concept_key <- decode.field("concept_key", decode.string)
  use term <- decode.field("term", decode.string)
  use definition <- decode.field("definition", decode.string)
  use context <- decode.field("context", decode.optional(decode.string))
  use examples <- decode.field("examples", decode.optional(decode.string))
  use anti_patterns <- decode.field(
    "anti_patterns",
    decode.optional(decode.string),
  )
  use related_concepts <- decode.field(
    "related_concepts",
    decode.optional(decode.list(decode.string)),
  )
  use category <- decode.field("category", decode.string)
  decode.success(KeyConcept(
    concept_key: concept_key,
    term: term,
    definition: definition,
    context: option.unwrap(context, ""),
    examples: option.unwrap(examples, ""),
    anti_patterns: option.unwrap(anti_patterns, ""),
    related_concepts: option.unwrap(related_concepts, []),
    category: category,
  ))
}
