// project.gleam — Project identification.
//
// A project is identified by a string, resolved once per session.
// No DB lookup. No env var. Cached after first read.
//
// Single source of truth: project_url().

import filepath
import gleam/option.{type Option, None, Some}
import gleam/string
import simplifile

/// Cached project URL. Read once, reused for the lifetime of the process.
/// The project URL doesn't change during a session.
/// Use get_project_url() to access the cached value.
pub fn project_url() -> String {
  case get_project_url() {
    Some(url) -> url
    None -> {
      let url = resolve_project_url()
      set_project_url(url)
      url
    }
  }
}

/// Resolve the project URL from disk (no caching).
fn resolve_project_url() -> String {
  let cwd = case simplifile.current_directory() {
    Ok(dir) -> dir
    Error(_) -> "unknown"
  }
  let git_config_path = filepath.join(cwd, ".git/config")

  case read_git_remote(git_config_path) {
    Ok(url) -> url
    Error(_) -> cwd
  }
}

@external(javascript, "./project_ffi.mjs", "get_project_url")
fn get_project_url() -> Option(String)

@external(javascript, "./project_ffi.mjs", "set_project_url")
fn set_project_url(url: String) -> Nil

fn read_git_remote(config_path: String) -> Result(String, Nil) {
  case simplifile.read(config_path) {
    Error(_) -> Error(Nil)
    Ok(content) -> parse_remote_origin(content)
  }
}

fn parse_remote_origin(config: String) -> Result(String, Nil) {
  let lines = string.split(config, "\n")

  // Walk lines looking for [remote "origin"] followed by url =
  let result =
    parse_remote_lines(lines, False)

  case result {
    Ok(url) ->
      Ok(normalise_remote_url(string.trim(url)))
    Error(_) -> Error(Nil)
  }
}

fn parse_remote_lines(
  lines: List(String),
  remote: Bool,
) -> Result(String, Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] ->
      case remote {
        True ->
          case string.starts_with(string.trim(line), "url") {
            True ->
              case string.split(string.trim(line), "=") {
                [_, url_part] -> Ok(string.trim(url_part))
                _ -> parse_remote_lines(rest, True)
              }
            False -> parse_remote_lines(rest, True)
          }
        False ->
          case string.trim(line) {
            "[remote \"origin\"]" ->
              parse_remote_lines(rest, True)
            _ -> parse_remote_lines(rest, False)
          }
      }
  }
}

fn normalise_remote_url(raw: String) -> String {
  // Remove trailing .git
  let without_dot_git = case string.ends_with(raw, ".git") {
    True -> string.slice(raw, 0, string.length(raw) - 4)
    False -> raw
  }
  // Remove trailing /
  case string.ends_with(without_dot_git, "/") {
    True -> string.slice(without_dot_git, 0, string.length(without_dot_git) - 1)
    False -> without_dot_git
  }
}

// ---------------------------------------------------------------------------
// Legacy types — kept for compatibility but no longer used for project_id.
// DB operations are simplified: project_url() replaces all project_id fields.
// ---------------------------------------------------------------------------

pub type ProjectStatus {
  Active
  Inactive
  Archived
}

pub type Project {
  Project(
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
