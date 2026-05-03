import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi_cli/db

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
  )
}

pub type IssueError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn severity_to_string(s: IssueSeverity) -> String {
  case s {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
    Cosmetic -> "cosmetic"
  }
}

fn string_to_severity(s: String) -> IssueSeverity {
  case s {
    "critical" -> Critical
    "high" -> High
    "low" -> Low
    "cosmetic" -> Cosmetic
    _ -> Medium
  }
}

fn status_to_string(s: IssueStatus) -> String {
  case s {
    Open -> "open"
    InProgress -> "in_progress"
    Resolved -> "resolved"
    Closed -> "closed"
  }
}

fn string_to_status(s: String) -> IssueStatus {
  case s {
    "in_progress" -> InProgress
    "resolved" -> Resolved
    "closed" -> Closed
    _ -> Open
  }
}

fn type_to_string(t: IssueType) -> String {
  case t {
    Bug -> "bug"
    Inconsistency -> "inconsistency"
    Feature -> "feature"
    Improvement -> "improvement"
    Question -> "question"
    Debt -> "debt"
  }
}

fn string_to_type(t: String) -> IssueType {
  case t {
    "inconsistency" -> Inconsistency
    "feature" -> Feature
    "improvement" -> Improvement
    "question" -> Question
    "debt" -> Debt
    _ -> Bug
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

  decode.success(Issue(
    id: id,
    title: title,
    description: description,
    severity: string_to_severity(severity_str),
    status: string_to_status(status_str),
    issue_type: string_to_type(issue_type_str),
    created_at: created_at,
    resolved_at: resolved_at,
    created_by: created_by,
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
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
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

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              case result.rows {
                [row, ..] -> {
                  case decode.run(row, id_decoder()) {
                    Ok(id) -> promise.resolve(Ok(id))
                    Error(_) -> promise.resolve(Error(DecodeError("Failed to decode id")))
                  }
                }
                _ -> promise.resolve(Error(NotFound("No id returned")))
              }
            }
          }
        })
      }
    }
  })
}

pub fn list(
  status: Option(String),
) -> promise.Promise(Result(List(Issue), IssueError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = case status {
          Some(_) -> "
            SELECT id, title, description, severity, status, issue_type,
                   created_at::text, resolved_at::text, created_by
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
                   created_at::text, resolved_at::text, created_by
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

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              let issues = result.rows
                |> list.map(fn(row) { decode.run(row, issue_decoder()) })
                |> list.filter_map(fn(r) { r })

              promise.resolve(Ok(issues))
            }
          }
        })
      }
    }
  })
}

pub fn resolve(
  issue_id: String,
  resolution: String,
) -> promise.Promise(Result(String, IssueError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = "
          UPDATE issues
          SET status = 'resolved', resolved_at = NOW(), resolution = $2
          WHERE id = $1
          RETURNING id
        "
        let params = [dynamic.string(issue_id), dynamic.string(resolution)]

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              case result.rows {
                [row, ..] -> {
                  case decode.run(row, id_decoder()) {
                    Ok(id) -> promise.resolve(Ok(id))
                    Error(_) -> promise.resolve(Error(DecodeError("Failed to decode id")))
                  }
                }
                _ -> promise.resolve(Error(NotFound("Issue not found")))
              }
            }
          }
        })
      }
    }
  })
}

pub fn get(
  issue_id: String,
) -> promise.Promise(Result(Issue, IssueError)) {
  promise.await(db.connect(), fn(conn_result) {
    case conn_result {
      Error(_) -> promise.resolve(Error(ConnectionError("Failed to connect")))
      Ok(conn) -> {
        let sql = "
          SELECT id, title, description, severity, status, issue_type,
                 created_at::text, resolved_at::text, created_by
          FROM issues
          WHERE id = $1
        "
        let params = [dynamic.string(issue_id)]

        promise.await(db.query(conn, sql, params), fn(query_result) {
          let _ = db.disconnect(conn)
          case query_result {
            Error(_) -> promise.resolve(Error(QueryError("Query failed")))
            Ok(result) -> {
              case result.rows {
                [row, ..] -> {
                  case decode.run(row, issue_decoder()) {
                    Ok(issue) -> promise.resolve(Ok(issue))
                    Error(_) -> promise.resolve(Error(DecodeError("Failed to decode issue")))
                  }
                }
                _ -> promise.resolve(Error(NotFound("Issue not found")))
              }
            }
          }
        })
      }
    }
  })
}
