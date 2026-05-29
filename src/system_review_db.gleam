import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import db
import system_review_types.{
  type ReviewError, type ReviewFinding, type SystemReview,
  ConnectionError, QueryError, NotFound, DecodeError,
  Medium, Open as FindingOpen,
  Pending, FuPending,
  string_to_review_type, string_to_review_status, string_to_methodology,
  string_to_scope, string_to_follow_up_status,
  string_to_finding_severity, string_to_finding_status,
}
import project as proj
  SystemReview, ReviewFinding,
}

fn db_error_to_review_error(e: db.DbError) -> ReviewError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn review_decoder() -> decode.Decoder(SystemReview) {
  use id <- decode.field("id", decode.string)
  use review_type_str <- decode.field("review_type", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use current_state <- decode.field("current_state", decode.optional(decode.string))
  use target_id <- decode.field("target_id", decode.optional(decode.string))
  use target_type <- decode.field("target_type", decode.optional(decode.string))
  use title <- decode.field("title", decode.optional(decode.string))
  use description <- decode.field("description", decode.optional(decode.string))
  use reviewer_id <- decode.field("reviewer_id", decode.optional(decode.string))
  use project_id <- decode.field("project_id", decode.optional(decode.string))
  use methodology_str <- decode.field("methodology", decode.optional(decode.string))
  use scope_str <- decode.field("scope", decode.optional(decode.string))
  use follow_up_status_str <- decode.field("follow_up_status", decode.string)
  use follow_up_due <- decode.field("follow_up_due", decode.optional(decode.string))
  use git_hash <- decode.field("git_hash", decode.optional(decode.string))
  use git_branch <- decode.field("git_branch", decode.optional(decode.string))
  use related_issue_id <- decode.field("related_issue_id", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use completed_at <- decode.field("completed_at", decode.optional(decode.string))

  let review_type = case review_type_str {
    Some(s) -> string_to_review_type(s) |> result_to_optional()
    None -> None
  }
  let methodology = case methodology_str {
    Some(s) -> string_to_methodology(s) |> result_to_optional()
    None -> None
  }
  let scope = case scope_str {
    Some(s) -> string_to_scope(s) |> result_to_optional()
    None -> None
  }
  let follow_up_status = case string_to_follow_up_status(follow_up_status_str) {
    Ok(s) -> s
    Error(_) -> FuPending
  }
  let status = case string_to_review_status(status_str) {
    Ok(s) -> s
    Error(_) -> Pending
  }

  decode.success(SystemReview(
    id: id,
    review_type: review_type,
    status: status,
    current_state: current_state,
    target_id: target_id,
    target_type: target_type,
    title: title,
    description: description,
    reviewer_id: reviewer_id,
    project_id: project_id,
    methodology: methodology,
    scope: scope,
    follow_up_status: follow_up_status,
    follow_up_due: follow_up_due,
    git_hash: git_hash,
    git_branch: git_branch,
    related_issue_id: related_issue_id,
    created_at: created_at,
    updated_at: updated_at,
    completed_at: completed_at,
  ))
}

fn result_to_optional(r: Result(a, String)) -> Option(a) {
  case r {
    Ok(v) -> Some(v)
    Error(_) -> None
  }
}

fn finding_decoder() -> decode.Decoder(ReviewFinding) {
  use id <- decode.field("id", decode.string)
  use review_id <- decode.field("review_id", decode.string)
  use finding_number <- decode.field("finding_number", decode.int)
  use severity_str <- decode.field("severity", decode.string)
  use category <- decode.field("category", decode.string)
  use module_ <- decode.field("module", decode.optional(decode.string))
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use evidence <- decode.field("evidence", decode.optional(decode.string))
  use impact <- decode.field("impact", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use related_issue_id <- decode.field("related_issue_id", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  use resolved_at <- decode.field("resolved_at", decode.optional(decode.string))

  let severity = case string_to_finding_severity(severity_str) {
    Ok(s) -> s
    Error(_) -> Medium
  }
  let status = case string_to_finding_status(status_str) {
    Ok(s) -> s
    Error(_) -> FindingOpen
  }

  decode.success(ReviewFinding(
    id: id,
    review_id: review_id,
    finding_number: finding_number,
    severity: severity,
    category: category,
    module: module_,
    title: title,
    description: description,
    evidence: evidence,
    impact: impact,
    status: status,
    related_issue_id: related_issue_id,
    created_at: created_at,
    updated_at: updated_at,
    resolved_at: resolved_at,
  ))
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

pub fn create_review(
  review_type: String,
  title: String,
  description: String,
  methodology: String,
  scope: String,
  reviewer_id: String,
  cwd: String,
) -> promise.Promise(Result(String, ReviewError)) {
  promise.await(proj.resolve_or_create(cwd), fn(project_result) {
    case project_result {
      Ok(p) -> create_review_with_project(review_type, title, description, methodology, scope, reviewer_id, p.id)
      Error(e) -> promise.resolve(Error(db_error_to_review_error(e)))
    }
  })
}

fn create_review_with_project(
  review_type: String,
  title: String,
  description: String,
  methodology: String,
  scope: String,
  reviewer_id: String,
  project_id: String,
) -> promise.Promise(Result(String, ReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO system_reviews (review_type, title, description, methodology, scope, reviewer_id, project_id, status)
      VALUES ($1, $2, $3, $4, $5, $6, $7, 'in_progress')
      RETURNING id::text
    "
    let params = [
      dynamic.string(review_type),
      dynamic.string(title),
      dynamic.string(description),
      dynamic.string(methodology),
      dynamic.string(scope),
      dynamic.string(reviewer_id),
      dynamic.string(project_id),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode review id"))
              }
            }
            _ -> Error(NotFound("No id returned"))
          }
        }
      }
    })
  }, db_error_to_review_error)
}

pub fn add_finding(
  review_id: String,
  finding_number: Int,
  severity: String,
  category: String,
  module: String,
  title: String,
  description: String,
  evidence: String,
  impact: String,
) -> promise.Promise(Result(String, ReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO review_findings (review_id, finding_number, severity, category, module, title, description, evidence, impact)
      VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING id::text
    "
    let params = [
      dynamic.string(review_id),
      dynamic.int(finding_number),
      dynamic.string(severity),
      dynamic.string(category),
      dynamic.string(module),
      dynamic.string(title),
      dynamic.string(description),
      dynamic.string(evidence),
      dynamic.string(impact),
    ]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode finding id"))
              }
            }
            _ -> Error(NotFound("No id returned"))
          }
        }
      }
    })
  }, db_error_to_review_error)
}

pub fn get_review(
  review_id: String,
) -> promise.Promise(Result(SystemReview, ReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id::text, review_type, status, current_state, target_id, target_type,
             title, description, reviewer_id, project_id::text,
             methodology, scope, follow_up_status,
             follow_up_due::text, git_hash, git_branch,
             related_issue_id::text,
             created_at::text, updated_at::text, completed_at::text
      FROM system_reviews
      WHERE id = $1::uuid
    "
    let params = [dynamic.string(review_id)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, review_decoder()) {
                Ok(review) -> Ok(review)
                Error(_) -> Error(DecodeError("Failed to decode review"))
              }
            }
            _ -> Error(NotFound("Review not found"))
          }
        }
      }
    })
  }, db_error_to_review_error)
}

pub fn list_reviews(
  status: Option(String),
  review_type: Option(String),
  limit: Int,
  offset: Int,
) -> promise.Promise(Result(List(SystemReview), ReviewError)) {
  db.with_connection(fn(conn) {
    let #(where_clause, where_params) = build_review_where(status, review_type)
    let param_count = list.length(where_params)
    let limit_idx = param_count + 1
    let offset_idx = param_count + 2
    let sql = "
      SELECT id::text, review_type, status, current_state, target_id, target_type,
             title, description, reviewer_id, project_id::text,
             methodology, scope, follow_up_status,
             follow_up_due::text, git_hash, git_branch,
             related_issue_id::text,
             created_at::text, updated_at::text, completed_at::text
      FROM system_reviews
      " <> where_clause <> " ORDER BY created_at DESC LIMIT $" <> string.inspect(limit_idx) <> " OFFSET $" <> string.inspect(offset_idx)
    let params = list.append(where_params, [dynamic.int(limit), dynamic.int(offset)])
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, review_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode review row"))
            Ok(reviews) -> Ok(reviews)
          }
        }
      }
    })
  }, db_error_to_review_error)
}

fn build_review_where(
  status: Option(String),
  review_type: Option(String),
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
  let #(conditions, params) = case review_type {
    Some(t) -> {
      let idx = list.length(params) + 1
      #(["review_type = $" <> string.inspect(idx), ..conditions], [dynamic.string(t), ..params])
    }
    None -> #(conditions, params)
  }
  case conditions {
    [] -> #("", [])
    _ -> #(" WHERE " <> string.join(list.reverse(conditions), " AND "), params)
  }
}

pub fn list_findings(
  review_id: String,
  severity: Option(String),
  status: Option(String),
  limit: Int,
  offset: Int,
) -> promise.Promise(Result(List(ReviewFinding), ReviewError)) {
  db.with_connection(fn(conn) {
    let #(where_clause, where_params) = build_finding_where(review_id, severity, status)
    let param_count = list.length(where_params)
    let limit_idx = param_count + 1
    let offset_idx = param_count + 2
    let sql = "
      SELECT id::text, review_id::text, finding_number, severity, category, module,
             title, description, evidence, impact, status,
             related_issue_id::text,
             created_at::text, updated_at::text, resolved_at::text
      FROM review_findings
      " <> where_clause <> " ORDER BY finding_number ASC LIMIT $" <> string.inspect(limit_idx) <> " OFFSET $" <> string.inspect(offset_idx)
    let params = list.append(where_params, [dynamic.int(limit), dynamic.int(offset)])
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, finding_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode finding row"))
            Ok(findings) -> Ok(findings)
          }
        }
      }
    })
  }, db_error_to_review_error)
}

fn build_finding_where(
  review_id: String,
  severity: Option(String),
  status: Option(String),
) -> #(String, List(dynamic.Dynamic)) {
  let conditions = []
  let params = []
  let #(conditions, params) = {
    let idx = list.length(params) + 1
    #(["review_id = $" <> string.inspect(idx) <> "::uuid", ..conditions], [dynamic.string(review_id), ..params])
  }
  let #(conditions, params) = case severity {
    Some(s) -> {
      let idx = list.length(params) + 1
      #(["severity = $" <> string.inspect(idx), ..conditions], [dynamic.string(s), ..params])
    }
    None -> #(conditions, params)
  }
  let #(conditions, params) = case status {
    Some(s) -> {
      let idx = list.length(params) + 1
      #(["status = $" <> string.inspect(idx), ..conditions], [dynamic.string(s), ..params])
    }
    None -> #(conditions, params)
  }
  case conditions {
    [] -> #("", [])
    _ -> #(" WHERE " <> string.join(list.reverse(conditions), " AND "), params)
  }
}

pub fn count_findings(
  review_id: String,
  severity: Option(String),
  status: Option(String),
) -> promise.Promise(Result(Int, ReviewError)) {
  db.with_connection(fn(conn) {
    let #(where_clause, where_params) = build_finding_where(review_id, severity, status)
    let sql = "SELECT COUNT(*)::INT as cnt FROM review_findings" <> where_clause
    promise.map(db.query(conn, sql, where_params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
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
  }, db_error_to_review_error)
}

pub fn update_finding_status(
  finding_id: String,
  new_status: String,
) -> promise.Promise(Result(String, ReviewError)) {
  db.with_connection(fn(conn) {
    let resolved_at = case new_status {
      "fixed" -> ", resolved_at = NOW()"
      "wont_fix" -> ", resolved_at = NOW()"
      "retracted" -> ", resolved_at = NOW()"
      _ -> ""
    }
    let sql = "
      UPDATE review_findings
      SET status = $2" <> resolved_at <> "
      WHERE id = $1::uuid
      RETURNING id::text
    "
    let params = [dynamic.string(finding_id), dynamic.string(new_status)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode finding id"))
              }
            }
            _ -> Error(NotFound("Finding not found"))
          }
        }
      }
    })
  }, db_error_to_review_error)
}

pub fn complete_review(
  review_id: String,
) -> promise.Promise(Result(String, ReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE system_reviews
      SET status = 'completed', completed_at = NOW(), current_state = 'completed'
      WHERE id = $1::uuid
      RETURNING id::text
    "
    let params = [dynamic.string(review_id)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode review id"))
              }
            }
            _ -> Error(NotFound("Review not found"))
          }
        }
      }
    })
  }, db_error_to_review_error)
}

pub fn severity_breakdown(
  review_id: String,
) -> promise.Promise(Result(List(#(String, Int)), ReviewError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT severity, COUNT(*)::INT as cnt
      FROM review_findings
      WHERE review_id = $1::uuid
      GROUP BY severity
      ORDER BY CASE severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
        WHEN 'cosmetic' THEN 5
      END
    "
    let params = [dynamic.string(review_id)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_review_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) {
              case decode.run(row, severity_count_decoder()) {
                Ok(pair) -> Ok(pair)
                Error(_) -> Error(DecodeError("Failed to decode severity count"))
              }
            })
          case decode_all_results(decoded) {
            Error(e) -> Error(e)
            Ok(pairs) -> Ok(pairs)
          }
        }
      }
    })
  }, db_error_to_review_error)
}

fn severity_count_decoder() -> decode.Decoder(#(String, Int)) {
  use severity <- decode.field("severity", decode.string)
  use cnt <- decode.field("cnt", decode.int)
  decode.success(#(severity, cnt))
}
