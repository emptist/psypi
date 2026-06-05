// project.gleam — Project identification.
//
// A project is identified by a string, resolved from the current directory
// every time. No caching — the directory can change at any time.
//
// Single source of truth: project_url().
//
// ☠️ CRITICAL: NEVER CACHE project_url()
// ─────────────────────────────────────────────────────────────────────
// The working directory can change at any time during a session (e.g. AI
// runs `cd /other/dir`). If you cache this value, you will silently use
// the wrong project_url for all subsequent DB operations (tasks, issues,
// reviews, etc.) — data goes to the wrong project and you won't know.
//
// This mistake has been made and documented. Do NOT reintroduce caching.
// Every call to project_url() MUST read simplifile.current_directory()
// fresh from the OS. The cost of a syscall is negligible compared to
// the cost of silent data corruption.
//
// Previous (WRONG) pattern — DO NOT REINTRODUCE:
//   let _cached = // module-level variable
//   pub fn project_url() -> String {
//     case get_cached() { Some(url) -> url, None -> resolve_and_cache() }
//   }
//
// Current (CORRECT) pattern:
//   pub fn project_url() -> String {
//     let cwd = simplifile.current_directory()  // always fresh
//     ...
//   }
// ─────────────────────────────────────────────────────────────────────

import filepath
import gleam/option.{type Option}
import gleam/string
import simplifile

/// Resolve the project URL from disk on every call.
/// Reads the current directory, checks for .git/config, returns git remote
/// or the raw cwd path.
pub fn project_url() -> String {
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
