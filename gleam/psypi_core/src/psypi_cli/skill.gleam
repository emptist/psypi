import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi_cli/db

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
        SELECT id, name, description, source, status, safety_score, version, author, created_at::text
        FROM skills
        WHERE status = $1
        ORDER BY name ASC
        LIMIT 100
      "
      None -> "
        SELECT id, name, description, source, status, safety_score, version, author, created_at::text
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
      SELECT id, name, description, source, status, safety_score, version, author, created_at::text
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
      SELECT id, name, description, source, status, safety_score, version, author, created_at::text
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
