// agent_identity.gleam — Agent identity resolution + enrichment from DB

import agent_identity_types.{
  type IdentityContext, type IdentityError, ConnectionError, QueryError, NotFound,
}
import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/string
import pi_tool_call.{type PiToolCall, PiToolCall, lit, raw_json}

// -------------------------------------------------------------------
// Types
// -------------------------------------------------------------------

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
  )
}

// -------------------------------------------------------------------
// Project & globals
// -------------------------------------------------------------------

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

// -------------------------------------------------------------------
// Semantic ID
// -------------------------------------------------------------------

fn semantic_id(ctx: IdentityContext) -> Result(String, IdentityError) {
  let prefix = case ctx.is_idle {
    True -> "A"
    False -> "S"
  }

  let global_prefix = case ctx.global {
    True -> "G-"
    False -> ""
  }

  case ctx.model {
    "" -> Error(NotFound("missing model id"))
    _ -> {
      let base =
        global_prefix
        <> prefix
        <> "-"
        <> ctx.project
        <> "-"
        <> ctx.source
        <> "-"
        <> ctx.model

      case ctx.thinking_level {
        "" -> Ok(base)
        tl -> Ok(base <> "-" <> tl)
      }
    }
  }
}

// -------------------------------------------------------------------
// DB helpers
// -------------------------------------------------------------------

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
    let sql = "SELECT id, name, domain, responsibility, trigger_type, drive_mode, activation FROM agent_souls WHERE id_prefix = $1 AND is_active = true LIMIT 1"
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

// -------------------------------------------------------------------
// Enriched identity: semantic ID + DB soul + tasks
// -------------------------------------------------------------------

pub fn get_enriched_identity(
  ctx: IdentityContext,
) -> promise.Promise(Result(EnrichedIdentity, IdentityError)) {
  let project = resolve_project(ctx.cwd)
  let _global = case check_git_exists(ctx.cwd) {
    True -> False
    False -> True
  }

  case semantic_id(ctx) {
    Ok(id) -> {
      let prefix = case string.contains(id, "A-") || ctx.is_idle {
        True -> "A"
        False -> "S"
      }

      promise.await(fetch_soul_by_prefix(prefix), fn(soul_result) {
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
              )))
          }
          Error(_) ->
            promise.resolve(Ok(EnrichedIdentity(
              id: id,
              prefix: prefix,
              role: prefix <> "-bot",
              name: prefix <> " Agentbot",
              domain: "unknown",
              responsibilities: "",
              trigger_type: "",
              drive_mode: "",
              activation: "",
              project: project,
              model: ctx.model,
              source: ctx.source,
              thinking_level: ctx.thinking_level,
            )))
        }
      })
    }
    Error(e) -> promise.resolve(Error(e))
  }
}

// -------------------------------------------------------------------
// Pi tool
// -------------------------------------------------------------------

/// Pi tool: psypi-my-id — get the calling agent's full identity (ID, role, responsibilities, tasks)
pub fn my_id_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-my-id",
    description: "Get the calling agent's full identity. Returns ID, prefix, role, name, domain, responsibilities, trigger_type, drive_mode, activation, project, model, source, and thinking_level.",
    params: [],
    module: "agent_identity",
    fn_name: "get_enriched_identity",
    args: [
      lit(
        "({ is_idle: ctx.isIdle(), source: (ctx.model?.provider || ''), "
        <> "model: (ctx.model?.id || ''), "
        <> "thinking_level: (ctx.model?.thinkingLevel || ''), "
        <> "cwd: (ctx.cwd || '') })",
      ),
    ],
    result_format: raw_json(),
  )
}
