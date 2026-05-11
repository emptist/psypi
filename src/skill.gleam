import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, opt_string_param, from_param, template}

pub type SkillSource {
  Clawhub
  Local
  Generated
  Imported
}

pub type SkillStatus {
  Pending
  Approved
  Rejected
  Blocked
  Installed
  Uninstalled
}

pub type Skill {
  Skill(
    id: String,
    name: String,
    description: Option(String),
    source: SkillSource,
    status: SkillStatus,
    safety_score: Int,
    version: String,
    author: Option(String),
    created_at: String,
    content: Option(String),
    reference_list: Option(String),
  )
}

pub type SkillError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn string_to_source(s: String) -> SkillSource {
  case s {
    "local" -> Local
    "generated" -> Generated
    "imported" -> Imported
    _ -> Clawhub
  }
}

fn string_to_status(s: String) -> SkillStatus {
  case s {
    "approved" -> Approved
    "rejected" -> Rejected
    "blocked" -> Blocked
    "installed" -> Installed
    "uninstalled" -> Uninstalled
    _ -> Pending
  }
}

fn skill_decoder() -> decode.Decoder(Skill) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use source_str <- decode.field("source", decode.string)
  use status_str <- decode.field("status", decode.string)
  use safety_score <- decode.field("safety_score", decode.int)
  use version <- decode.field("version", decode.string)
  use author <- decode.field("author", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use content <- decode.field("content", decode.optional(decode.string))
  use reference_list <- decode.field("reference_list", decode.optional(decode.string))

  decode.success(Skill(
    id: id,
    name: name,
    description: description,
    source: string_to_source(source_str),
    status: string_to_status(status_str),
    safety_score: safety_score,
    version: version,
    author: author,
    created_at: created_at,
    content: content,
    reference_list: reference_list,
  ))
}

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn db_error_to_skill_error(e: db.DbError) -> SkillError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn list(
  status: Option(SkillStatus),
) -> promise.Promise(Result(List(Skill), SkillError)) {
  db.with_connection(fn(conn) {
    let sql = case status {
      Some(_) -> "
        SELECT id, name, description, source, status, safety_score, version, author, created_at::text, content::text, reference_list::text
        FROM skills
        WHERE status = $1
        ORDER BY name ASC
        LIMIT 100
      "
      None -> "
        SELECT id, name, description, source, status, safety_score, version, author, created_at::text, content::text, reference_list::text
        FROM skills
        ORDER BY name ASC
        LIMIT 100
      "
    }

    let params = case status {
      Some(s) -> [dynamic.string(case s {
        Pending -> "pending"
        Approved -> "approved"
        Rejected -> "rejected"
        Blocked -> "blocked"
        Installed -> "installed"
        Uninstalled -> "uninstalled"
      })]
      None -> []
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_error(e))
        Ok(result) -> {
          let skills = result.rows
            |> list.map(fn(row) { decode.run(row, skill_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(skills)
        }
      }
    })
  }, db_error_to_skill_error)
}

pub fn get(
  name: String,
) -> promise.Promise(Result(Skill, SkillError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, name, description, source, status, safety_score, version, author, created_at::text, content, reference_list
      FROM skills
      WHERE name = $1
    "
    let params = [dynamic.string(name)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, skill_decoder()) {
                Ok(skill) -> Ok(skill)
                Error(_) -> Error(DecodeError("Failed to decode skill"))
              }
            }
            _ -> Error(NotFound("Skill not found"))
          }
        }
      }
    })
  }, db_error_to_skill_error)
}

pub fn search(
  query: String,
) -> promise.Promise(Result(List(Skill), SkillError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id, name, description, source, status, safety_score, version, author, created_at::text, content, reference_list
      FROM skills
      WHERE name ILIKE $1 OR description ILIKE $1
      ORDER BY name ASC
      LIMIT 50
    "
    let params = [dynamic.string("%" <> query <> "%")]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_error(e))
        Ok(result) -> {
          let skills = result.rows
            |> list.map(fn(row) { decode.run(row, skill_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(skills)
        }
      }
    })
  }, db_error_to_skill_error)
}

pub fn create(
  name: String,
  description: String,
  author: String,
) -> promise.Promise(Result(String, SkillError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO skills (name, description, status, safety_score, author)
      VALUES ($1, $2, 'pending', 0, $3)
      RETURNING id
    "
    let params = [
      dynamic.string(name),
      dynamic.string(description),
      dynamic.string(author),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_error(e))
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
  }, db_error_to_skill_error)
}

pub fn approve(
  skill_id: String,
  approved_by: String,
) -> promise.Promise(Result(String, SkillError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE skills
      SET status = 'approved', approved_by = $2, approved_at = NOW()
      WHERE id = $1
      RETURNING id
    "
    let params = [dynamic.string(skill_id), dynamic.string(approved_by)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("Skill not found"))
          }
        }
      }
    })
  }, db_error_to_skill_error)
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-skill-list — list skills
pub fn skill_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-skill-list",
    description: "List skills, optionally filtered by status",
    params: [opt_string_param("status")],
    module: "skill",
    fn_name: "list",
    args: [from_param("params?.status || null")],
    result_format: template("Skills: ${JSON.stringify(r.value)}"),
  )
}

/// Pi tool: psypi-skill-get — get a skill by ID
pub fn skill_get_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-skill-get",
    description: "Get a skill by ID",
    params: [string_param("id")],
    module: "skill",
    fn_name: "get",
    args: [from_param("params.id || \"\"")],
    result_format: template("Skill: ${JSON.stringify(r.value)}"),
  )
}

/// Pi tool: psypi-skill-search — search skills by name
pub fn skill_search_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-skill-search",
    description: "Search skills by name",
    params: [string_param("query")],
    module: "skill",
    fn_name: "search",
    args: [from_param("params.query || \"\"")],
    result_format: template("Search results: ${JSON.stringify(r.value)}"),
  )
}
