import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import psypi_cli/db.{type DbError, type Connection, with_connection}
import psypi_cli/pi_tool_call.{type PiToolCall, PiToolCall, raw_json, from_param, string_param}

// Save a file version to database
// Returns: Ok(version_id) or Error(DbError)
pub fn save_version(
  file_path: String,
  content: String,
  saved_by: String,
  commit_hash: String,
  reason: String,
) -> promise.Promise(Result(String, DbError)) {
  with_connection(
    fn(conn: Connection) {
      let sql = "
        SELECT save_code_version(
          $1::TEXT,  -- file_path
          $2::TEXT,  -- content
          $3::VARCHAR, -- saved_by
          $4::VARCHAR, -- commit_hash
          $5::TEXT      -- reason
        ) as version_id
      "
      
      let params = [
        dynamic.string(file_path),
        dynamic.string(content),
        dynamic.string(saved_by),
        dynamic.string(commit_hash),
        dynamic.string(reason),
      ]

      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Ok(query_result) -> {
            case query_result.rows {
              [row] -> {
                case decode.run(row, version_id_decoder()) {
                  Ok(id) -> Ok(id)
                  Error(_) -> Error(db.QueryError("Failed to decode version_id"))
                }
              }
              _ -> Error(db.QueryError("No version_id returned"))
            }
          }
          Error(e) -> Error(e)
        }
      })
    },
    fn(e: DbError) { e }
  )
}

// Get version history for a file
// Returns: Ok(list of version rows) or Error(DbError)
pub fn get_versions(
  file_path: String,
  limit: Int,
) -> promise.Promise(Result(List(dynamic.Dynamic), DbError)) {
  with_connection(
    fn(conn: Connection) {
      let sql = "
        SELECT * FROM get_code_versions(
          $1::TEXT,  -- file_path
          $2::INTEGER -- limit
        )
      "
      
      let params = [
        dynamic.string(file_path),
        dynamic.int(limit),
      ]

      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Ok(query_result) -> Ok(query_result.rows)
          Error(e) -> Error(e)
        }
      })
    },
    fn(e: DbError) { e }
  )
}

// Restore a specific version
// Returns: Ok(content) or Error(DbError)
pub fn restore_version(
  version_id: String,
) -> promise.Promise(Result(String, DbError)) {
  with_connection(
    fn(conn: Connection) {
      let sql = "
        SELECT restore_code_version(
          $1::UUID
        ) as content
      "
      
      let params = [dynamic.string(version_id)]

      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Ok(query_result) -> {
            case query_result.rows {
              [row] -> {
                case decode.run(row, content_decoder()) {
                  Ok(content) -> Ok(content)
                  Error(_) -> Error(db.QueryError("Failed to decode content"))
                }
              }
              _ -> Error(db.QueryError("No content returned"))
            }
          }
          Error(e) -> Error(e)
        }
      })
    },
    fn(e: DbError) { e }
  )
}

// Decoder for version_id (UUID string)
fn version_id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("version_id", decode.string)
  decode.success(id)
}

// Decoder for content (text)
fn content_decoder() -> decode.Decoder(String) {
  use content <- decode.field("content", decode.string)
  decode.success(content)
}

// -------------------------------------------------------------------
// Pi Tool Call definition
// -------------------------------------------------------------------

/// Pi tool: psypi-doc-save — save a file version to database
pub fn doc_save_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-doc-save",
    description: "Save a file version to code_versions table (auto-backup before AI edits)",
    params: [string_param("file_path")],
    module: "code_version",
    fn_name: "save_version",
    args: [
      from_param("params.file_path"),
      from_param("params.content || \"\""),
      from_param("params.saved_by || \"unknown\""),
      from_param("params.commit_hash || \"\""),
      from_param("params.reason || \"manual save\""),
    ],
    result_format: raw_json(),
  )
}

// Query code_versions table with optional filters
// Returns: Ok(list of version rows) or Error(DbError)
pub fn query_versions(
  file_path_pattern: String,
  saved_by_filter: String,
  search_content: String,
  limit: Int,
) -> promise.Promise(Result(List(dynamic.Dynamic), DbError)) {
  with_connection(
    fn(conn: Connection) {
      let sql = "
        SELECT 
          id, file_path, saved_by, saved_at,
          LEFT(content, 200) as content_preview,
          LENGTH(content) as content_length
        FROM code_versions
        WHERE 1=1
        AND ($1::TEXT = '' OR file_path LIKE $1)
        AND ($2::VARCHAR = '' OR saved_by = $2)
        AND ($3::TEXT = '' OR content LIKE $3)
        ORDER BY saved_at DESC
        LIMIT $4
      "
      
      // Add % wildcards for LIKE patterns
      let file_pattern = case file_path_pattern {
        "" -> ""
        path -> "%" <> path <> "%"
      }
      
      let content_pattern = case search_content {
        "" -> ""
        content -> "%" <> content <> "%"
      }
      
      let params = [
        dynamic.string(file_pattern),
        dynamic.string(saved_by_filter),
        dynamic.string(content_pattern),
        dynamic.int(limit),
      ]

      promise.map(db.query(conn, sql, params), fn(result) {
        case result {
          Ok(query_result) -> Ok(query_result.rows)
          Error(e) -> Error(e)
        }
      })
    },
    fn(e: DbError) { e }
  )
}
