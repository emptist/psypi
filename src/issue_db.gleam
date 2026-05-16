// issue_db.gleam — Issue database queries

import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db
import issue_types.{type Issue, type IssueError, ConnectionError, QueryError, DecodeError, NotFound, Medium, Open, Bug, string_to_severity, string_to_status, string_to_type}

fn db_error_to_issue_error(e: db.DbError) -> IssueError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn issue_decoder() -> decode.Decoder(Issue) {
  use id <- decode.field("id", decode.string)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use severity_str <- decode.field("severity", decode.string)
  use status_str <- decode.field("status", decode.string)
  use issue_type_str <- decode.field("issue_type", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use resolved_at <- decode.field("resolved_at", decode.optional(decode.string))
  use created_by <- decode.field("created_by", decode.string)
  use discovered_by <- decode.field("discovered_by", decode.optional(decode.string))
  use environment <- decode.field("environment", decode.optional(decode.string))
  use git_branch <- decode.field("git_branch", decode.optional(decode.string))
  use git_hash <- decode.field("git_hash", decode.optional(decode.string))
  use reported_by <- decode.field("reported_by", decode.optional(decode.string))
  use source <- decode.field("source", decode.optional(decode.string))

  let severity = case string_to_severity(severity_str) {
    Ok(s) -> s
    Error(_) -> Medium
  }
  let status = case string_to_status(status_str) {
    Ok(s) -> s
    Error(_) -> Open
  }
  let issue_type = case string_to_type(issue_type_str) {
    Ok(t) -> t
    Error(_) -> Bug
  }
  decode.success(issue_types.Issue(
    id: id,
    title: title,
    description: description,
    severity: severity,
    status: status,
    issue_type: issue_type,
    created_at: created_at,
    resolved_at: resolved_at,
    created_by: created_by,
    discovered_by: discovered_by,
    environment: environment,
    git_branch: git_branch,
    git_hash: git_hash,
    reported_by: reported_by,
    source: source,
  ))
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

pub fn add(
  title: String,
  description: String,
  severity: String,
  issue_type: String,
  created_by: String,
) -> promise.Promise(Result(String, IssueError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO issues (title, description, severity, issue_type, created_by)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
    "
    let params = [
      dynamic.string(title),
      dynamic.string(description),
      dynamic.string(severity),
      dynamic.string(issue_type),
      dynamic.string(created_by),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("No id returned"))
          }
        }
      }
    })
  }, db_error_to_issue_error)
}

pub fn list(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  limit: Int,
  offset: Int,
) -> promise.Promise(Result(List(Issue), IssueError)) {
  db.with_connection(fn(conn) {
    let #(sql, params) = sql_with_filters(status, severity, issue_type, limit, offset)
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          let issues = result.rows
            |> list.map(fn(row) { decode.run(row, issue_decoder()) })
            |> list.filter_map(fn(r) { r })
          Ok(issues)
        }
      }
    })
  }, db_error_to_issue_error)
}

fn sql_with_filters(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  limit: Int,
  offset: Int,
) -> #(String, List(dynamic.Dynamic)) {
  // Use hardcoded SQL for each filter combination to avoid $ interpolation issues
  case status, severity, issue_type {
    Some(s), Some(sev), Some(t) ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE status = $1 AND severity = $2 AND issue_type = $3 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $4 OFFSET $5",
        [dynamic.string(s), dynamic.string(sev), dynamic.string(t), dynamic.int(limit), dynamic.int(offset)])
    Some(s), Some(sev), None ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE status = $1 AND severity = $2 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $3 OFFSET $4",
        [dynamic.string(s), dynamic.string(sev), dynamic.int(limit), dynamic.int(offset)])
    Some(s), None, Some(t) ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE status = $1 AND issue_type = $2 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $3 OFFSET $4",
        [dynamic.string(s), dynamic.string(t), dynamic.int(limit), dynamic.int(offset)])
    Some(s), None, None ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE status = $1 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $2 OFFSET $3",
        [dynamic.string(s), dynamic.int(limit), dynamic.int(offset)])
    None, Some(sev), Some(t) ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE severity = $1 AND issue_type = $2 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $3 OFFSET $4",
        [dynamic.string(sev), dynamic.string(t), dynamic.int(limit), dynamic.int(offset)])
    None, Some(sev), None ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE severity = $1 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $2 OFFSET $3",
        [dynamic.string(sev), dynamic.int(limit), dynamic.int(offset)])
    None, None, Some(t) ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues WHERE issue_type = $1 ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $2 OFFSET $3",
        [dynamic.string(t), dynamic.int(limit), dynamic.int(offset)])
    None, None, None ->
      #("SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $1 OFFSET $2",
        [dynamic.int(limit), dynamic.int(offset)])
  }
}

fn sql_count_with_filters(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
) -> #(String, List(dynamic.Dynamic)) {
  case status, severity, issue_type {
    Some(s), Some(sev), Some(t) ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE status = $1 AND severity = $2 AND issue_type = $3",
        [dynamic.string(s), dynamic.string(sev), dynamic.string(t)])
    Some(s), Some(sev), None ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE status = $1 AND severity = $2",
        [dynamic.string(s), dynamic.string(sev)])
    Some(s), None, Some(t) ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE status = $1 AND issue_type = $2",
        [dynamic.string(s), dynamic.string(t)])
    Some(s), None, None ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE status = $1",
        [dynamic.string(s)])
    None, Some(sev), Some(t) ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE severity = $1 AND issue_type = $2",
        [dynamic.string(sev), dynamic.string(t)])
    None, Some(sev), None ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE severity = $1",
        [dynamic.string(sev)])
    None, None, Some(t) ->
      #("SELECT COUNT(*)::INT as cnt FROM issues WHERE issue_type = $1",
        [dynamic.string(t)])
    None, None, None ->
      #("SELECT COUNT(*)::INT as cnt FROM issues",
        [])
  }
}

pub fn count(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
) -> promise.Promise(Result(Int, IssueError)) {
  db.with_connection(fn(conn) {
    let #(sql, params) = sql_count_with_filters(status, severity, issue_type)
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, decode.int) {
                Ok(n) -> Ok(n)
                Error(_) -> Ok(0)
              }
            }
            _ -> Ok(0)
          }
        }
      }
    })
  }, db_error_to_issue_error)
}

pub fn get(
  issue_id: String,
) -> promise.Promise(Result(Issue, IssueError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, title, description, severity, status, issue_type,
             created_at::text, resolved_at::text, created_by,
             discovered_by, environment, git_branch, git_hash, reported_by, source
      FROM issues
      WHERE id = $1
    "
    let params = [dynamic.string(issue_id)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, issue_decoder()) {
                Ok(issue) -> Ok(issue)
                Error(_) -> Error(DecodeError("Failed to decode issue"))
              }
            }
            _ -> Error(NotFound("Issue not found"))
          }
        }
      }
    })
  }, db_error_to_issue_error)
}

pub fn resolve(
  issue_id: String,
  resolution: String,
) -> promise.Promise(Result(String, IssueError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE issues
      SET status = 'resolved', resolved_at = NOW(), resolution = $2
      WHERE id = $1
      RETURNING id
    "
    let params = [dynamic.string(issue_id), dynamic.string(resolution)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("Issue not found"))
          }
        }
      }
    })
  }, db_error_to_issue_error)
}
