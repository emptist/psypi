import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, opt_string_param, from_param, template}

pub type IssueSeverity {
  Critical
  High
  Medium
  Low
  Cosmetic
}

pub type IssueStatus {
  Open
  InProgress
  Resolved
  Closed
}

pub type IssueType {
  Bug
  Inconsistency
  Feature
  Improvement
  Question
  Debt
}

pub type Issue {
  Issue(
    id: String,
    title: String,
    description: Option(String),
    severity: IssueSeverity,
    status: IssueStatus,
    issue_type: IssueType,
    created_at: String,
    resolved_at: Option(String),
    created_by: String,
    discovered_by: Option(String),
    environment: Option(String),
    git_branch: Option(String),
    git_hash: Option(String),
    reported_by: Option(String),
    source: Option(String),
  )
}

pub type IssueError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

pub fn string_to_severity(s: String) -> Result(IssueSeverity, String) {
  case s {
    "critical" -> Ok(Critical)
    "high" -> Ok(High)
    "medium" -> Ok(Medium)
    "low" -> Ok(Low)
    "cosmetic" -> Ok(Cosmetic)
    _ -> Error("Invalid severity: " <> s <> ". Allowed: critical, high, medium, low, cosmetic")
  }
}

pub fn string_to_status(s: String) -> Result(IssueStatus, String) {
  case s {
    "open" -> Ok(Open)
    "in_progress" -> Ok(InProgress)
    "resolved" -> Ok(Resolved)
    "closed" -> Ok(Closed)
    _ -> Error("Invalid status: " <> s <> ". Allowed: open, in_progress, resolved, closed")
  }
}

pub fn string_to_type(t: String) -> Result(IssueType, String) {
  case t {
    "bug" -> Ok(Bug)
    "inconsistency" -> Ok(Inconsistency)
    "feature" -> Ok(Feature)
    "improvement" -> Ok(Improvement)
    "question" -> Ok(Question)
    "debt" -> Ok(Debt)
    _ -> Error("Invalid issue_type: " <> t <> ". Allowed: bug, inconsistency, feature, improvement, question, debt")
  }
}

pub fn severity_to_string(s: IssueSeverity) -> String {
  case s {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
    Cosmetic -> "cosmetic"
  }
}

pub fn type_to_string(t: IssueType) -> String {
  case t {
    Bug -> "bug"
    Inconsistency -> "inconsistency"
    Feature -> "feature"
    Improvement -> "improvement"
    Question -> "question"
    Debt -> "debt"
  }
}

pub fn issue_decoder() -> decode.Decoder(Issue) {
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
  decode.success(Issue(
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

pub fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn db_error_to_issue_error(e: db.DbError) -> IssueError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn add(
  title: String,
  description: String,
  severity: String,
  issue_type: String,
  created_by: String,
) -> promise.Promise(Result(String, IssueError)) {
  case string_to_severity(severity) {
    Error(e) -> promise.resolve(Error(QueryError(e)))
    Ok(severity_val) -> {
      case string_to_type(issue_type) {
        Error(e) -> promise.resolve(Error(QueryError(e)))
        Ok(type_val) -> {
          db.with_connection(fn(conn) {
            let sql = "
              INSERT INTO issues (title, description, severity, issue_type, created_by)
              VALUES ($1, $2, $3, $4, $5)
              RETURNING id
            "
            let params = [
              dynamic.string(title),
              dynamic.string(description),
              dynamic.string(severity_to_string(severity_val)),
              dynamic.string(type_to_string(type_val)),
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
      }
    }
  }
}

pub fn list(
  status: Option(String),
) -> promise.Promise(Result(List(Issue), IssueError)) {
  db.with_connection(fn(conn) {
    let sql = case status {
      Some(_) -> "
        SELECT id, title, description, severity, status, issue_type,
               created_at::text, resolved_at::text, created_by,
               discovered_by, environment, git_branch, git_hash, reported_by, source
        FROM issues
        WHERE status = $1
        ORDER BY 
          CASE severity 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'medium' THEN 3 
            WHEN 'low' THEN 4 
            ELSE 5 
          END,
          created_at DESC
        LIMIT 100
      "
      None -> "
        SELECT id, title, description, severity, status, issue_type,
               created_at::text, resolved_at::text, created_by,
               discovered_by, environment, git_branch, git_hash, reported_by, source
        FROM issues
        ORDER BY 
          CASE severity 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'medium' THEN 3 
            WHEN 'low' THEN 4 
            ELSE 5 
          END,
          created_at DESC
        LIMIT 100
      "
    }

    let params = case status {
      Some(s) -> [dynamic.string(s)]
      None -> []
    }

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

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-issue-add — add a new issue
pub fn issue_add_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-add",
    description: "Add a new issue",
    params: [
      string_param("title"),
      string_param("description"),
      string_param("severity"),
      string_param("issue_type"),
    ],
    module: "issue",
    fn_name: "add",
    args: [
      from_param("params.title || \"\""),
      from_param("params.description || \"\""),
      from_param("params.severity || \"medium\""),
      from_param("params.issue_type || \"bug\""),
      from_param("params.created_by || \"psypi\""),
    ],
    result_format: template("Issue added: ${r.value}"),
  )
}

/// Pi tool: psypi-issues — list issues
pub fn issue_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issues",
    description: "List issues, optionally filtered by status",
    params: [opt_string_param("status")],
    module: "issue",
    fn_name: "list",
    args: [from_param("params?.status || null")],
    result_format: template("Issues: ${JSON.stringify(r.value)}"),
  )
}

/// Pi tool: psypi-issue-resolve — resolve an issue
pub fn issue_resolve_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-issue-resolve",
    description: "Resolve an issue by ID",
    params: [string_param("id")],
    module: "issue",
    fn_name: "resolve",
    args: [from_param("params.id || \"\"")],
    result_format: template("Issue resolved: ${r.value}"),
  )
}
