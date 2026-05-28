// project.gleam — Project type and database operations
//
// Projects are the top-level organizational unit in psypi.
// Every task, issue, meeting, skill, broadcast, and review belongs to a project.
// The current project is determined from ctx.cwd or the PSYPI_PROJECT_ID env var.

import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}

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

fn db_error_to_project_error(e: db.DbError) -> ProjectError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

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

  case string_to_status(status_str) {
    Error(_) -> decode.failure(Project(id: id, name: name, description: description, path: path, language: language, framework: framework, status: Active, git_remote: git_remote, fingerprint: fingerprint, created_at: created_at, updated_at: updated_at, last_seen: last_seen, last_qc_at: last_qc_at), "Unknown project status: " <> status_str)
    Ok(status) -> decode.success(Project(
      id: id,
      name: name,
      description: description,
      path: path,
      language: language,
      framework: framework,
      status: status,
      git_remote: git_remote,
      fingerprint: fingerprint,
      created_at: created_at,
      updated_at: updated_at,
      last_seen: last_seen,
      last_qc_at: last_qc_at,
    ))
  }
}

/// Look up a project by its filesystem path.
/// This is the primary way to identify the current project from ctx.cwd.
pub fn get_by_path(path: String) -> promise.Promise(Result(Project, ProjectError)) {
  db.with_connection(fn(conn) {
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
                Ok(project) -> Ok(project)
                Error(_) -> Error(DecodeError("Failed to decode project"))
              }
            _ -> Error(NotFound("No project at path: " <> path))
          }
      }
    })
  }, db_error_to_project_error)
}

/// Look up a project by ID.
pub fn get_by_id(id: String) -> promise.Promise(Result(Project, ProjectError)) {
  db.with_connection(fn(conn) {
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
            _ -> Error(NotFound("No project with id: " <> id))
          }
      }
    })
  }, db_error_to_project_error)
}

/// Resolve a project_id string: "ALL" → None (all projects), valid UUID → Some(id), empty → current project from env.
pub fn resolve_project_id(
  raw: String,
) -> promise.Promise(Result(Option(String), ProjectError)) {
  case raw {
    "" -> {
      // Default: look up current project from PSYPI_PROJECT_ID env or cwd-based lookup
      promise.resolve(Ok(None))
    }
    "ALL" -> promise.resolve(Ok(None))
    id ->
      promise.map(get_by_id(id), fn(result) {
        case result {
          Ok(_) -> Ok(Some(id))
          Error(_) -> Error(NotFound("Project not found: " <> id))
        }
      })
  }
}

/// Get the current active project (single-project setup fallback).
/// Returns the only ACTIVE project, or an error if zero or multiple exist.
pub fn get_current() -> promise.Promise(Result(Project, ProjectError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id::text, name, description, path, language, framework,
             status, git_remote, fingerprint,
             created_at::text, updated_at::text, last_seen::text, last_qc_at::text
      FROM projects
      WHERE status = 'ACTIVE'
      ORDER BY name ASC
      LIMIT 1
    "
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_project_error(e))
        Ok(result) ->
          case result.rows {
            [row, ..] ->
              case decode.run(row, project_decoder()) {
                Ok(project) -> Ok(project)
                Error(_) -> Error(DecodeError("Failed to decode project"))
              }
            _ -> Error(NotFound("No active project found"))
          }
      }
    })
  }, db_error_to_project_error)
}
