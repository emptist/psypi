// issue_db.gleam — Issue database queries

import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import issue_types.{
  type Issue, type IssueError, ConnectionError, QueryError, DecodeError, NotFound,
  Medium, Open, Bug, string_to_severity, string_to_status, string_to_type,
}
import project.{project_url}

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

  case string_to_severity(severity_str) {
    Error(_) -> decode.failure(issue_types.Issue(id:, title:, description:, severity: Medium, status: Open, issue_type: Bug, created_at:, resolved_at:, created_by:, discovered_by:, environment:, git_branch:, git_hash:, reported_by:, source:), "Unknown severity: " <> severity_str)
    Ok(severity) -> {
      case string_to_status(status_str) {
        Error(_) -> decode.failure(issue_types.Issue(id:, title:, description:, severity:, status: Open, issue_type: Bug, created_at:, resolved_at:, created_by:, discovered_by:, environment:, git_branch:, git_hash:, reported_by:, source:), "Unknown status: " <> status_str)
        Ok(status) -> {
          case string_to_type(issue_type_str) {
            Error(_) -> decode.failure(issue_types.Issue(id:, title:, description:, severity:, status:, issue_type: Bug, created_at:, resolved_at:, created_by:, discovered_by:, environment:, git_branch:, git_hash:, reported_by:, source:), "Unknown issue_type: " <> issue_type_str)
            Ok(issue_type) -> decode.success(issue_types.Issue(
              id:, title:, description:, severity:, status:, issue_type:,
              created_at:, resolved_at:, created_by:, discovered_by:, environment:,
              git_branch:, git_hash:, reported_by:, source:,
            ))
          }
        }
      }
    }
  }
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn count_decoder() -> decode.Decoder(Int) {
  use cnt <- decode.field("cnt", decode.int)
  decode.success(cnt)
}

fn decode_all_results(results: List(Result(a, b))) -> Result(List(a), b) {
  case results {
    [] -> Ok([])
    [Ok(v), ..rest] -> {
      case decode_all_results(rest) {
        Error(e) -> Error(e)
        Ok(vs) -> Ok([v, ..vs])
      }
    }
    [Error(e), .._] -> Error(e)
  }
}

pub fn add(
  title: String,
  description: String,
  severity: String,
  issue_type: String,
  created_by: String,
) -> promise.Promise(Result(String, IssueError)) {
  let project_url = project_url()
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO issues (title, description, severity, issue_type, created_by, project_url)
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id
    "
    let params = [
      dynamic.string(title),
      dynamic.string(description),
      dynamic.string(severity),
      dynamic.string(issue_type),
      dynamic.string(created_by),
      dynamic.string(project_url),
    ]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
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
  project_url_arg: Option(String),
  limit: Int,
  offset: Int,
) -> promise.Promise(Result(List(Issue), IssueError)) {
  let project_url = case project_url_arg {
    Some("ALL") -> None
    Some(p) -> Some(p)
    None -> Some(project_url())
  }
  db.with_connection(fn(conn) {
    let #(sql, params) = sql_with_filters(status, severity, issue_type, project_url, limit, offset)
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, issue_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode issue row"))
            Ok(issues) -> Ok(issues)
          }
        }
      }
    })
  }, db_error_to_issue_error)
}

fn sql_with_filters(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  project_url: Option(String),
  limit: Int,
  offset: Int,
) -> #(String, List(dynamic.Dynamic)) {
  let base_sql = "SELECT id, title, description, severity, status, issue_type, created_at::text, resolved_at::text, created_by, discovered_by, environment, git_branch, git_hash, reported_by, source FROM issues"
  let #(where_clause, where_params) = build_where(status, severity, issue_type, project_url)
  let param_count = list.length(where_params)
  let limit_idx = param_count + 1
  let offset_idx = param_count + 2
  let order_limit = " ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END, created_at DESC LIMIT $" <> string.inspect(limit_idx) <> " OFFSET $" <> string.inspect(offset_idx)
  #(base_sql <> where_clause <> order_limit, list.append(where_params, [dynamic.int(limit), dynamic.int(offset)]))
}

fn build_where(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  project_url: Option(String),
) -> #(String, List(dynamic.Dynamic)) {
  let conditions = []
  let params = []
  let #(conditions, params) = case status {
    Some(s) -> {
      let idx = list.length(params) + 1
      #(["status = $" <> string.inspect(idx), ..conditions], [dynamic.string(s), ..params])
    }
    None -> #(conditions, params)
  }
  let #(conditions, params) = case severity {
    Some(s) -> {
      let idx = list.length(params) + 1
      #(["severity = $" <> string.inspect(idx), ..conditions], [dynamic.string(s), ..params])
    }
    None -> #(conditions, params)
  }
  let #(conditions, params) = case issue_type {
    Some(t) -> {
      let idx = list.length(params) + 1
      #(["issue_type = $" <> string.inspect(idx), ..conditions], [dynamic.string(t), ..params])
    }
    None -> #(conditions, params)
  }
  let #(conditions, params) = case project_url {
    None -> #(conditions, params)
    Some(p) -> {
      let idx = list.length(params) + 1
      #(["project_url = $" <> string.inspect(idx), ..conditions], [dynamic.string(p), ..params])
    }
  }
  case conditions {
    [] -> #("", [])
    _ -> #(" WHERE " <> string.join(list.reverse(conditions), " AND "), params)
  }
}

fn sql_count_with_filters(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  project_url: Option(String),
) -> #(String, List(dynamic.Dynamic)) {
  let base_sql = "SELECT COUNT(*)::INT as cnt FROM issues"
  let #(where_clause, where_params) = build_where(status, severity, issue_type, project_url)
  #(base_sql <> where_clause, where_params)
}

pub fn count(
  status: Option(String),
  severity: Option(String),
  issue_type: Option(String),
  project_url_arg: Option(String),
) -> promise.Promise(Result(Int, IssueError)) {
  let project_url = case project_url_arg {
    Some("ALL") -> None
    Some(p) -> Some(p)
    None -> Some(project_url())
  }
  db.with_connection(fn(conn) {
    let #(sql, params) = sql_count_with_filters(status, severity, issue_type, project_url)
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_issue_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, count_decoder()) {
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

pub fn get(issue_id: String) -> promise.Promise(Result(Issue, IssueError)) {
  let project_url = project_url()
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, title, description, severity, status, issue_type,
             created_at::text, resolved_at::text, created_by,
             discovered_by, environment, git_branch, git_hash, reported_by, source
      FROM issues
      WHERE id = $1 AND project_url = $2
    "
    let params = [dynamic.string(issue_id), dynamic.string(project_url)]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
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

pub fn resolve(issue_id: String, resolution: String) -> promise.Promise(Result(String, IssueError)) {
  let project_url = project_url()
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE issues
      SET status = 'resolved', resolved_at = NOW(), resolution = $2
      WHERE id = $1 AND project_url = $3
      RETURNING id
    "
    let params = [dynamic.string(issue_id), dynamic.string(resolution), dynamic.string(project_url)]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
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
