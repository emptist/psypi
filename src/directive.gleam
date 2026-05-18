import agent_identity_types.{IdentityContext, resolved_identity}
import db
import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import pi_tool_call.{
  type PiToolCall, PiToolCall, from_param, opt_string_param, string_param,
  template,
}

pub type DirectiveError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

fn db_error_to_directive_error(e: db.DbError) -> DirectiveError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn soul_decoder() -> decode.Decoder(String) {
  use name <- decode.field("name", decode.string)
  use traits <- decode.field("traits", decode.optional(decode.string))
  let quote = case traits {
    Some(t) -> " — " <> string.slice(t, 0, 80)
    None -> ""
  }
  decode.success(name <> quote)
}

/// Set a system directive — Atonomic Agentbot uses this to direct Somatic Agentbot.
/// Gets the Atonomic identity (model-aware) and includes SOUL context.
///
/// model_id and thinking_level come from the live ctx.model in the tool wrapper.
pub fn set_directive(
  directive_text: String,
  priority: String,
  model_id: String,
  thinking_level: String,
) -> promise.Promise(Result(String, DirectiveError)) {
  db.with_connection(
    fn(conn) {
      // 1. Get Atonomic identity (autonomous=true → A- prefix)
      //    ID format: A-psypi-psypi-<model_id>[-<thinking_level>]
      // Extract provider from model_id (e.g., "openrouter" from "openrouter/owl-alpha")
      let provider = case string.split(model_id, "/") {
        [p, ..] -> p
        _ -> "unknown"
      }
      let identity =
        resolved_identity(IdentityContext(
          is_idle: True,
          project: "psypi",
          source: provider,
          model: model_id,
          thinking_level: thinking_level,
          global: False,
        ))
      case identity {
        Error(_) -> promise.resolve(Error(QueryError("Identity error")))
        Ok(id_val) -> {
          let agent_id = id_val.id
          // 2. Query SOUL from database
          let soul_sql =
            "SELECT name, traits FROM souls WHERE agent_id = $1 LIMIT 1"
          promise.await(
            db.query(conn, soul_sql, [dynamic.string(agent_id)]),
            fn(soul_result) {
              let soul_prefix = case soul_result {
                Error(_) -> "[Atonomic] "
                Ok(soul_rows) -> {
                  case soul_rows.rows {
                    [soul_row, ..] -> {
                      case decode.run(soul_row, soul_decoder()) {
                        Ok(quote) -> "[" <> quote <> "] "
                        Error(_) -> "[Atonomic] "
                      }
                    }
                    _ -> "[Atonomic] "
                  }
                }
              }
              // 3. Insert directive with SOUL context
              let full_text = soul_prefix <> directive_text
              let sql =
                "
            INSERT INTO system_directives (agent_id, directive_text, priority, source, expires_at)
            VALUES ($1, $2, $3, 'autonomic', NOW() + INTERVAL '1 hour')
            ON CONFLICT (agent_id, directive_text, is_active) DO UPDATE SET
              priority = EXCLUDED.priority,
              created_at = NOW(),
              expires_at = NOW() + INTERVAL '1 hour',
              consumed_at = NULL
            RETURNING id::text
          "
              let params = [
                dynamic.string(agent_id),
                dynamic.string(full_text),
                dynamic.string(priority),
              ]
              promise.map(db.query(conn, sql, params), fn(insert_result) {
                case insert_result {
                  Error(e) -> Error(db_error_to_directive_error(e))
                  Ok(_) -> Ok("Directive set: " <> full_text)
                }
              })
            },
          )
        }
      }
    },
    db_error_to_directive_error,
  )
}

/// Clear all active directives
pub fn clear_directives() -> promise.Promise(Result(String, DirectiveError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      UPDATE system_directives 
      SET is_active = false, consumed_at = NOW()
      WHERE agent_id IN (SELECT agent_id FROM souls WHERE active = true)
        AND is_active = true
    "
      promise.map(db.query(conn, sql, []), fn(result) {
        case result {
          Error(e) -> Error(db_error_to_directive_error(e))
          Ok(_) -> Ok("Directives cleared")
        }
      })
    },
    db_error_to_directive_error,
  )
}

/// Get active directives for an agent
pub fn get_active_directives(
  agent_id: String,
) -> promise.Promise(Result(List(String), DirectiveError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      SELECT directive_text, priority
      FROM system_directives
      WHERE agent_id = $1 
        AND is_active = true
        AND (expires_at IS NULL OR expires_at > NOW())
        AND consumed_at IS NULL
      ORDER BY 
        CASE priority 
          WHEN 'critical' THEN 1 
          WHEN 'high' THEN 2 
          WHEN 'medium' THEN 3 
          ELSE 4 
        END,
        created_at ASC
      LIMIT 3
    "
      promise.map(db.query(conn, sql, [dynamic.string(agent_id)]), fn(result) {
        case result {
          Error(e) -> Error(db_error_to_directive_error(e))
          Ok(query_result) -> {
            let directives =
              query_result.rows
              |> list.map(fn(row) {
                let text = dynamic.classify(row)
                text
              })
            Ok(directives)
          }
        }
      })
    },
    db_error_to_directive_error,
  )
}

/// Mark directives as consumed
pub fn mark_directives_consumed(
  agent_id: String,
) -> promise.Promise(Result(Nil, DirectiveError)) {
  db.with_connection(
    fn(conn) {
      let sql =
        "
      UPDATE system_directives 
      SET consumed_at = NOW(), is_active = false
      WHERE agent_id = $1 AND is_active = true AND consumed_at IS NULL
    "
      promise.map(db.query(conn, sql, [dynamic.string(agent_id)]), fn(result) {
        case result {
          Error(e) -> Error(db_error_to_directive_error(e))
          Ok(_) -> Ok(Nil)
        }
      })
    },
    db_error_to_directive_error,
  )
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

pub fn direct_agentbot_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-direct-agentbot",
    description: "Direct the Somatic Agentbot. Only the Autonomic Agentbot should use this. Gets Autonomic identity (model-aware from ctx), includes SOUL context. The directive will be injected into the Somatic Agentbot's system prompt on its next turn.",
    params: [
      string_param("directive_text"),
      opt_string_param("priority"),
    ],
    module: "directive",
    fn_name: "set_directive",
    args: [
      from_param("params.directive_text || \"\""),
      from_param("params.priority || \"medium\""),
      // model_id from ctx.model.id — live reference, always current
      from_param("ctx.model?.id || ''"),
      // thinking_level from ctx — empty string when off/unavailable
      from_param("(ctx.model?.thinkingLevel || '')"),
    ],
    result_format: template("${r.value}"),
  )
}

pub fn clear_directives_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-clear-directives",
    description: "Clear all active system directives.",
    params: [],
    module: "directive",
    fn_name: "clear_directives",
    args: [],
    result_format: template("${r.value}"),
  )
}
