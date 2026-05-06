import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import psypi_cli/db

pub type Skill {
  Skill(
    id: String,
    name: String,
    version: String,
    description: String,
    category: String,
  )
}

pub type SkillSystemError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_skill_system_error(e: db.DbError) -> SkillSystemError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

/// Decoder for Skill
fn skill_decoder() -> decode.Decoder(Skill) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use version <- decode.field("version", decode.string)
  use description <- decode.field("description", decode.string)
  use category <- decode.field("category", decode.string)
  decode.success(Skill(id:, name:, version:, description:, category:))
}

/// Get skill by name
pub fn get_skill(
  name: String,
) -> promise.Promise(Result(Skill, SkillSystemError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT id, name, version, description, category FROM skills WHERE name = $1 LIMIT 1"
    let params = [dynamic.string(name)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_system_error(e))
        Ok(result) -> {
          case result.rows {
            [] -> Error(QueryError("Skill not found: " <> name))
            [row, ..] -> {
              case decode.run(row, skill_decoder()) {
                Ok(skill) -> Ok(skill)
                Error(_) -> Error(DecodeError("Failed to decode skill"))
              }
            }
          }
        }
      }
    })
  }, db_error_to_skill_system_error)
}

/// List all skills
pub fn list_skills() -> promise.Promise(Result(List(Skill), SkillSystemError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT id, name, version, description, category FROM skills ORDER BY name"
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_skill_system_error(e))
        Ok(result) -> {
          let skills = result.rows
            |> list.map(fn(row) {
              case decode.run(row, skill_decoder()) {
                Ok(skill) -> [skill]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(skills)
        }
      }
    })
  }, db_error_to_skill_system_error)
}
