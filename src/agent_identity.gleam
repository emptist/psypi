import agent_identity_types.{
  type IdentityContext, type IdentityError, IdentityContext, ConnectionError,
  QueryError, NotFound, semantic_id,
}
import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/string
import pi_tool_call.{type PiToolCall, PiToolCall, lit, raw_json}
import simplifile

/// Get the current working directory from the OS.
/// NEVER use ctx.cwd — it is captured at session start and never updates.
fn current_cwd() -> String {
  case simplifile.current_directory() {
    Ok(dir) -> dir
    Error(_) -> ""
  }
}

pub type EnrichedIdentity {
  EnrichedIdentity(
    id: String,
    prefix: String,
    role: String,
    name: String,
    domain: String,
    responsibilities: String,
    trigger_type: String,
    drive_mode: String,
    activation: String,
    project: String,
    model: String,
    source: String,
    thinking_level: String,
    jobs: List(String),
  )
}

fn resolve_project(cwd: String) -> String {
  case cwd {
    "" -> "non-project"
    _ -> {
      let parts = string.split(cwd, "/") |> list.filter(fn(s) { s != "" })
      case list.last(parts) {
        Ok(dir) -> dir
        Error(_) -> "non-project"
      }
    }
  }
}

@external(javascript, "./agent_identity_ffi.mjs", "check_git_exists")
fn check_git_exists(cwd: String) -> Bool

pub fn compute_id(
  is_idle: Bool,
  source: String,
  model: String,
  thinking_level: String,
) -> String {
  let cwd = current_cwd()
  let project = resolve_project(cwd)
  let global = case check_git_exists(cwd) {
    True -> False
    False -> True
  }
  let ctx = IdentityContext(
    is_idle: is_idle,
    project: project,
    source: source,
    model: model,
    thinking_level: thinking_level,
    global: global,
    cwd: cwd,
  )
  case semantic_id(ctx) {
    Ok(id) -> id
    Error(_) -> ""
  }
}

fn db_error_to_identity_error(e: db.DbError) -> IdentityError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn soul_decoder() -> decode.Decoder(#(String, String, String, String, String, String, String)) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use domain <- decode.field("domain", decode.string)
  use responsibility <- decode.field("responsibility", decode.string)
  use trigger_type <- decode.field("trigger_type", decode.string)
  use drive_mode <- decode.field("drive_mode", decode.string)
  use activation <- decode.field("activation", decode.string)
  decode.success(#(id, name, domain, responsibility, trigger_type, drive_mode, activation))
}

fn fetch_soul_by_prefix(
  prefix: String,
) -> promise.Promise(Result(#(String, String, String, String, String, String, String), IdentityError)) {
  db.with_connection(fn(conn) {
    let sql = "SELECT id, name, domain, responsibility, trigger_type, drive_mode, activation FROM agent_souls WHERE id_prefix = $1 AND is_active = true AND is_archived = false LIMIT 1"
    let params = [dynamic.string(prefix)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_identity_error(e))
        Ok(result) ->
          case result.rows {
            [row, ..] ->
              case decode.run(row, soul_decoder()) {
                Ok(s) -> Ok(s)
                Error(_) -> Error(QueryError("Failed to decode soul"))
              }
            _ -> Error(NotFound("No soul found for prefix: " <> prefix))
          }
      }
    })
  }, db_error_to_identity_error)
}

fn job_row_decoder() -> decode.Decoder(String) {
  use job <- decode.field("job", decode.string)
  use priority <- decode.field("priority", decode.int)
  use category <- decode.field("category", decode.string)
  decode.success(int.to_string(priority) <> ". [" <> category <> "] " <> job)
}

fn fetch_jobs_by_prefix(prefix: String) -> promise.Promise(Result(List(String), IdentityError)) {
  db.with_connection(fn(conn) {
    let sql =
      "SELECT j.job, j.priority, j.category "
      <> "FROM agent_jobs j "
      <> "JOIN agent_souls s ON j.soul_id = s.id "
      <> "WHERE s.id_prefix = $1 AND j.is_active = true AND j.is_archived = false "
      <> "ORDER BY j.priority ASC"
    let params = [dynamic.string(prefix)]
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_identity_error(e))
        Ok(result) ->
          case result.rows {
            [] -> Ok([])
            rows ->
              rows
              |> list.map(fn(row) { decode.run(row, job_row_decoder()) })
              |> list.filter_map(fn(r) {
                case r {
                  Ok(v) -> Ok(v)
                  Error(_) -> Error(Nil)
                }
              })
              |> Ok
          }
      }
    })
  }, db_error_to_identity_error)
}

pub fn get_enriched_identity(
  ctx: IdentityContext,
) -> promise.Promise(Result(EnrichedIdentity, IdentityError)) {
  // Read current directory from OS — NOT from ctx.cwd
  let cwd = current_cwd()
  let project = resolve_project(cwd)
  let global = case check_git_exists(cwd) {
    True -> False
    False -> True
  }

  let resolved_ctx = IdentityContext(
    is_idle: ctx.is_idle,
    project: project,
    source: ctx.source,
    model: ctx.model,
    thinking_level: ctx.thinking_level,
    global: global,
    cwd: cwd,
  )

  let prefix = case ctx.is_idle {
    True -> "A"
    False -> "S"
  }

  case semantic_id(resolved_ctx) {
    Ok(id) -> {
      promise.await(fetch_soul_by_prefix(prefix), fn(soul_result) {
        promise.await(fetch_jobs_by_prefix(prefix), fn(jobs_result) {
          let jobs = case jobs_result {
            Ok(j) -> j
            Error(_) -> []
          }
          case soul_result {
            Ok(#(_soul_id, name, domain, responsibility, trigger_type, drive_mode, activation)) -> {
              promise.resolve(Ok(EnrichedIdentity(
                  id: id,
                  prefix: prefix,
                  role: name,
                  name: name,
                  domain: domain,
                  responsibilities: responsibility,
                  trigger_type: trigger_type,
                  drive_mode: drive_mode,
                  activation: activation,
                  project: project,
                  model: ctx.model,
                  source: ctx.source,
                  thinking_level: ctx.thinking_level,
                  jobs: jobs,
                )))
            }
            Error(e) -> promise.resolve(Error(e))
          }
        })
      })
    }
    Error(e) -> promise.resolve(Error(e))
  }
}

pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get the calling agent's full identity. Returns ID, prefix, role, name, domain, responsibilities, trigger_type, drive_mode, activation, project, model, source, thinking_level, and jobs.",
    params: [],
    module: "agent_identity",
    fn_name: "get_enriched_identity",
    args: [
      lit(
        "({ is_idle: ctx.isIdle(), source: (ctx.model?.provider || ''), "
        <> "model: (ctx.model?.id || ''), "
        <> "thinking_level: (ctx.model?.thinkingLevel || '') })",
      ),
    ],
    result_format: raw_json(),
  )
}
