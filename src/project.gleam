// project.gleam — Project type and database operations.
//
// A project is identified by its filesystem path (from ctx.cwd).
// The project_id is resolved fresh every time from the projects table.
// If the path doesn't match any existing project, a new one is auto-created.
// The database is shared across multiple projects. Old data without project_id
// is preserved for historic study but is invisible to psypi tools.

import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/option.{type Option}
import gleam/string

pub type ProjectStatus {
  Active
  Inactive
  Archived
}

pub type Project {
  Project(
    id: String,
    name: String,
    description: Option(String),
    path: String,
    language: Option(String),
    framework: Option(String),
    status: ProjectStatus,
    git_remote: Option(String),
    fingerprint: Option(String),
    created_at: String,
    updated_at: String,
    last_seen: String,
    last_qc_at: Option(String),
  )
}

pub type ProjectError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

// -------------------------------------------------------------------
// Converters
// -------------------------------------------------------------------

pub fn string_to_status(s: String) -> Result(ProjectStatus, String) {
  case s {
    "ACTIVE" -> Ok(Active)
    "INACTIVE" -> Ok(Inactive)
    "ARCHIVED" -> Ok(Archived)
    _ -> Error("Invalid project status: " <> s)
  }
}

pub fn status_to_string(s: ProjectStatus) -> String {
  case s {
    Active -> "ACTIVE"
    Inactive -> "INACTIVE"
    Archived -> "ARCHIVED"
  }
}

// -------------------------------------------------------------------
// Decoder
// -------------------------------------------------------------------

fn db_error_to_project_error(e: db.DbError) -> ProjectError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn project_decoder() -> decode.Decoder(Project) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use path <- decode.field("path", decode.string)
  use language <- decode.field("language", decode.optional(decode.string))
  use framework <- decode.field("framework", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use git_remote <- decode.field("git_remote", decode.optional(decode.string))
  use fingerprint <- decode.field("fingerprint", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use last_seen <- decode.field("last_seen", decode.string)
  use last_qc_at <- decode.field("last_qc_at", decode.optional(decode.string))

  let status = case string_to_status(status_str) {
    Ok(s) -> s
    Error(_) -> Active
  }

  decode.success(Project(
    id:,
    name:,
    description:,
    path:,
    language:,
    framework:,
    status:,
    git_remote:,
    fingerprint:,
    created_at:,
    updated_at:,
    last_seen:,
    last_qc_at:,
  ))
}

fn decode_rows(
  rows: List(dynamic.Dynamic),
  decoder: decode.Decoder(a),
) -> Result(List(a), ProjectError) {
  case rows {
    [] -> Ok([])
    [row, ..rest] ->
      case decode.run(row, decoder) {
        Ok(value) ->
          case decode_rows(rest, decoder) {
            Ok(vs) -> Ok([value, ..vs])
            Error(e) -> Error(e)
          }
        Error(_) -> Error(DecodeError("Failed to decode row"))
      }
  }
}

// -------------------------------------------------------------------
// Queries
// -------------------------------------------------------------------

pub fn resolve_by_path(
  path: String,
) -> promise.Promise(Result(Project, ProjectError)) {
  db.with_connection(
    fn(conn) {
      let sql = "
        SELECT id::text, name, description, path, language, framework,
               status, git_remote, fingerprint,
               created_at::text, updated_at::text, last_seen::text, last_qc_at::text
        FROM projects
        WHERE path = $1
      "
      let params = [dynamic.string(path)]
      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_project_error(e))
          Ok(result) ->
            case result.rows {
              [row, ..] ->
                case decode.run(row, project_decoder()) {
                  Ok(project) ->
                    Ok(project)
                  Error(_) ->
                    Error(DecodeError("Failed to decode project"))
                }
              [] ->
                Error(NotFound("No project at path: " <> path))
            }
        }
      })
    },
    db_error_to_project_error,
  )
}

pub fn get_by_id(
  id: String,
) -> promise.Promise(Result(Project, ProjectError)) {
  db.with_connection(
    fn(conn) {
      let sql = "
        SELECT id::text, name, description, path, language, framework,
               status, git_remote, fingerprint,
               created_at::text, updated_at::text, last_seen::text, last_qc_at::text
        FROM projects
        WHERE id = $1::uuid
      "
      let params = [dynamic.string(id)]
      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_project_error(e))
          Ok(result) ->
            case result.rows {
              [row, ..] ->
                case decode.run(row, project_decoder()) {
                  Ok(project) -> Ok(project)
                  Error(_) -> Error(DecodeError("Failed to decode project"))
                }
              [] ->
                Error(NotFound("No project with id: " <> id))
            }
        }
      })
    },
    db_error_to_project_error,
  )
}

pub fn list_active() -> promise.Promise(Result(List(Project), ProjectError)) {
  db.with_connection(
    fn(conn) {
      let sql = "
        SELECT id::text, name, description, path, language, framework,
               status, git_remote, fingerprint,
               created_at::text, updated_at::text, last_seen::text, last_qc_at::text
        FROM projects
        WHERE status = 'ACTIVE'
        ORDER BY name ASC
      "
      promise.map(db.query(conn, sql, []), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_project_error(e))
          Ok(result) ->
            case decode_rows(result.rows, project_decoder()) {
              Ok(projects) -> Ok(projects)
              Error(e) -> Error(e)
            }
        }
      })
    },
    db_error_to_project_error,
  )
}

/// Resolve the project for a path, auto-creating a new one if not found.
pub fn resolve_or_create(
  path: String,
) -> promise.Promise(Result(Project, ProjectError)) {
  promise.await(resolve_by_path(path), fn(result) {
    case result {
      Ok(project) -> promise.resolve(Ok(project))
      Error(NotFound(_)) -> insert_project(path)
      Error(other) -> promise.resolve(Error(other))
    }
  })
}

fn insert_project(
  path: String,
) -> promise.Promise(Result(Project, ProjectError)) {
  let name = project_name_from_path(path)
  db.with_connection(
    fn(conn) {
      let sql = "
        INSERT INTO projects (name, path, status)
        VALUES ($1, $2, 'ACTIVE')
        ON CONFLICT (path) DO UPDATE SET
          last_seen = NOW(),
          updated_at = NOW()
        RETURNING id::text, name, description, path, language, framework,
                  status, git_remote, fingerprint,
                  created_at::text, updated_at::text, last_seen::text, last_qc_at::text
      "
      let params = [dynamic.string(name), dynamic.string(path)]
      promise.map(db.query(conn, sql, params), fn(query_result) {
        case query_result {
          Error(e) -> Error(db_error_to_project_error(e))
          Ok(result) ->
            case result.rows {
              [row, ..] ->
                case decode.run(row, project_decoder()) {
                  Ok(p) -> Ok(p)
                  Error(_) -> Error(DecodeError("Failed to decode new project"))
                }
              [] ->
                Error(QueryError("No project returned after insert"))
            }
        }
      })
    },
    db_error_to_project_error,
  )
}

// -------------------------------------------------------------------
// Helpers
// -------------------------------------------------------------------

fn project_name_from_path(path: String) -> String {
  let parts = string.split(path, "/")
  case list_reverse(parts) {
    [last, ..] ->
      case last {
        "" -> path
        name -> name
      }
    _ -> path
  }
}

fn list_reverse(list: List(a)) -> List(a) {
  list_reverse_loop(list, [])
}

fn list_reverse_loop(list: List(a), acc: List(a)) -> List(a) {
  case list {
    [] -> acc
    [first, ..rest] -> list_reverse_loop(rest, [first, ..acc])
  }
}
