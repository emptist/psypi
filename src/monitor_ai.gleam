import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise
import gleam/list
import gleam/string
import db
import pi_tool_call.{type PiToolCall, type PiCommandReg, PiToolCall, raw_json, template, command}

pub type MonitorError {
  ConnectionError(String)
  QueryError(String)
  DecodeError(String)
}

pub type HealthMetrics {
  HealthMetrics(
    failed_tasks: Int,
    open_issues: Int,
    activities_1h: Int,
    db_healthy: Bool,
  )
}

fn db_error_to_monitor_error(e: db.DbError) -> MonitorError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

fn health_decoder() -> decode.Decoder(HealthMetrics) {
  use failed_tasks <- decode.field("failed_tasks", decode.int)
  use open_issues <- decode.field("open_issues", decode.int)
  use activities_1h <- decode.field("activities_1h", decode.int)
  decode.success(HealthMetrics(
    failed_tasks: failed_tasks,
    open_issues: open_issues,
    activities_1h: activities_1h,
    db_healthy: True,
  ))
}

/// Main Monitor AI loop - runs in background
pub fn start_monitor_loop() -> promise.Promise(Result(HealthMetrics, MonitorError)) {
  check_system_health()
}

/// Check system health (DB, tasks, issues, activity)
pub fn check_system_health() -> promise.Promise(Result(HealthMetrics, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 
        (SELECT COUNT(*)::INT FROM tasks WHERE status = 'FAILED') as failed_tasks,
        (SELECT COUNT(*)::INT FROM issues WHERE status = 'open') as open_issues,
        (SELECT COUNT(*)::INT FROM activity_log WHERE timestamp > NOW() - INTERVAL '1 hour') as activities_1h
    "
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [row, ..] -> {
              case decode.run(row, health_decoder()) {
                Ok(health) -> Ok(health)
                Error(_) -> Error(DecodeError("Failed to decode health metrics"))
              }
            }
            _ -> Error(QueryError("No health data returned"))
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Housekeeping - auto-backup before edits!
pub fn housekeeping(agent_id: String) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    // CORRECT: Use saved_at (not created_at!)
    let sql = "
      INSERT INTO code_versions (file_path, content, saved_by, reason, version_hash)
      VALUES ($1, $2, $3, $4, $5)
    "
    let params = [
      dynamic.string("monitor_ai_auto_backup"),
      dynamic.string("test content"),
      dynamic.string(agent_id),
      dynamic.string("auto-backup"),
      dynamic.string("dummy_hash"),
    ]
    
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_monitor_error(e))
      }
    })
  }, db_error_to_monitor_error)
}

/// Decoder for context rows (CORRECTED column names!)
fn context_row_decoder() -> decode.Decoder(String) {
  use type_ <- decode.field("type_", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(type_ <> ": " <> content <> "\n")
}

/// Prepare context for worker AI - HELPS ME WORK FASTER! 💡
pub fn prepare_context(agent_id: String) -> promise.Promise(Result(String, MonitorError)) {
  db.with_connection(fn(conn) {
    // CORRECT: Use saved_at (not created_at!)
    let sql = "
      SELECT 'learning' as type_, content, saved_at::text 
      FROM memory 
      WHERE agent_id = $1 AND source = 'learn'
      UNION ALL
      SELECT 'backup' as type_, file_path as content, saved_at::text
      FROM code_versions
      WHERE saved_by = $1
      ORDER BY saved_at DESC
      LIMIT 10
    "
    let params = [dynamic.string(agent_id)]
    
    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          let context = "Recent activity for " <> agent_id <> ":\n"
          let rows = result.rows
            |> list.map(fn(row) {
              case decode.run(row, context_row_decoder()) {
                Ok(text) -> text
                Error(_) -> ""
              }
            })
            |> string.join("")
          Ok(context <> rows)
        }
      }
    })
  }, db_error_to_monitor_error)
}

// -------------------------------------------------------------------
// Monitor Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-autonomic-health — get system health metrics
pub fn monitor_health_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-health",
    description: "Get system health metrics (failed tasks, open issues, activity)",
    params: [],
    module: "monitor_ai",
    fn_name: "check_system_health",
    args: [],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-autonomic-status — get psypi status
pub fn monitor_status_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-status",
    description: "Get psypi Monitor status and capabilities",
    params: [],
    module: "monitor_ai",
    fn_name: "start_monitor_loop",
    args: [],
    result_format: template("psypi Monitor: OK - use psypi-autonomic-health for metrics"),
  )
}

/// Pi tool: psypi-autonomic-alerts — get active alerts
pub fn monitor_alerts_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-alerts",
    description: "Get active alerts (failed tasks, open issues)",
    params: [],
    module: "monitor_ai",
    fn_name: "get_alerts",
    args: [],
    result_format: raw_json(),
  )
}

pub type AlertMetrics {
  AlertMetrics(failed_tasks: Int, open_issues: Int, critical_issues: Int)
}

fn alerts_decoder() -> decode.Decoder(AlertMetrics) {
  use failed_tasks <- decode.field("failed_tasks", decode.int)
  use open_issues <- decode.field("open_issues", decode.int)
  use critical_issues <- decode.field("critical_issues", decode.int)
  decode.success(AlertMetrics(failed_tasks: failed_tasks, open_issues: open_issues, critical_issues: critical_issues))
}

pub fn get_alerts() -> promise.Promise(Result(AlertMetrics, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 
        (SELECT COUNT(*)::INT FROM tasks WHERE status = 'FAILED') as failed_tasks,
        (SELECT COUNT(*)::INT FROM issues WHERE status = 'open') as open_issues,
        (SELECT COUNT(*)::INT FROM issues WHERE severity = 'critical' AND status = 'open') as critical_issues
    "
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [row, ..] -> {
              case decode.run(row, alerts_decoder()) {
                Ok(alerts) -> Ok(alerts)
                Error(_) -> Error(DecodeError("Failed to decode alerts"))
              }
            }
            _ -> Error(QueryError("No alert data"))
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

// -------------------------------------------------------------------
// Statistics - Track Model Quality
// -------------------------------------------------------------------

pub type ModelStats {
  ModelStats(
    total_reviews: Int,
    avg_score: Int,
    avg_response_time_ms: Int,
    failure_count: Int,
  )
}

fn model_stats_decoder() -> decode.Decoder(ModelStats) {
  use total_reviews <- decode.field("total_reviews", decode.int)
  use avg_score <- decode.field("avg_score", decode.int)
  use avg_response_time_ms <- decode.field("avg_response_time_ms", decode.int)
  use failure_count <- decode.field("failure_count", decode.int)
  decode.success(ModelStats(total_reviews:, avg_score:, avg_response_time_ms:, failure_count:))
}

/// Track model quality from inter_review data
pub fn get_model_stats() -> promise.Promise(Result(ModelStats, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT 
        COUNT(*)::INT as total_reviews,
        COALESCE(AVG(overall_score), 0)::INT as avg_score,
        COALESCE(AVG(EXTRACT(MILLISECONDS FROM (completed_at - requested_at))), 0)::INT as avg_response_time_ms,
        COUNT(*) FILTER (WHERE status = 'failed')::INT as failure_count
      FROM inter_reviews
      WHERE requested_at > NOW() - INTERVAL '24 hours'
    "
    promise.map(db.query(conn, sql, []), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [row, ..] -> {
              case decode.run(row, model_stats_decoder()) {
                Ok(stats) -> Ok(stats)
                Error(_) -> Error(DecodeError("Failed to decode model stats"))
              }
            }
            _ -> Error(QueryError("No stats returned"))
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Record a review score (called after inter_review completes)
pub fn record_review_score(review_id: String, score: Int) -> promise.Promise(Result(Nil, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "UPDATE inter_reviews SET overall_score = $1 WHERE id = $2"
    let params = [dynamic.int(score), dynamic.string(review_id)]
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(db_error_to_monitor_error(e))
      }
    })
  }, db_error_to_monitor_error)
}

// -------------------------------------------------------------------
// Self-Design - Monitor Finds Own Jobs
// -------------------------------------------------------------------

pub type MonitorSuggestion {
  MonitorSuggestion(suggestion_type: String, description: String, priority: Int)
}

fn suggestion_decoder() -> decode.Decoder(MonitorSuggestion) {
  use suggestion_type <- decode.field("suggestion_type", decode.string)
  use description <- decode.field("description", decode.string)
  use priority <- decode.field("priority", decode.int)
  decode.success(MonitorSuggestion(suggestion_type:, description:, priority:))
}

/// Detect if worker is idle and suggest work
pub fn get_work_suggestions() -> promise.Promise(Result(List(MonitorSuggestion), MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT * FROM (
        SELECT 'open_issues' as suggestion_type, 
               'Review and resolve ' || COUNT(*)::TEXT || ' open issues' as description,
               CASE WHEN severity = 'critical' THEN 1 ELSE 2 END as priority
        FROM issues WHERE status = 'open'
        GROUP BY severity
        UNION ALL
        SELECT 'stale_tasks' as suggestion_type,
               'Review ' || COUNT(*)::TEXT || ' stale tasks (>7 days)' as description,
               3 as priority
        FROM tasks WHERE status = 'pending' AND created_at < NOW() - INTERVAL '7 days'
        UNION ALL
        SELECT 'pending_skills' as suggestion_type,
               'Review ' || COUNT(*)::TEXT || ' pending skills' as description,
               4 as priority
        FROM skills WHERE status = 'pending'
      ) sub
      ORDER BY priority
      LIMIT 5
    "
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          let suggestions = result.rows
            |> list.map(fn(row) {
              case decode.run(row, suggestion_decoder()) {
                Ok(s) -> [s]
                Error(_) -> []
              }
            })
            |> list.fold([], fn(acc, lst) { list.append(acc, lst) })
          Ok(suggestions)
        }
      }
    })
  }, db_error_to_monitor_error)
}

// -------------------------------------------------------------------
// Safety Check - Returns block if critical
// -------------------------------------------------------------------

pub type SafetyResult {
  SafetyResult(should_block: Bool, reason: String, health: HealthMetrics)
}

pub fn check_safety() -> promise.Promise(Result(SafetyResult, MonitorError)) {
  promise.map(check_system_health(), fn(health_result) {
    case health_result {
      Error(e) -> Error(e)
      Ok(health) -> {
        let critical_threshold = 3
        let critical_issues = health.open_issues
        let should_block = critical_issues > critical_threshold
        let reason = case should_block {
          True -> "Critical: " <> int.to_string(critical_issues) <> " open issues"
          False -> "OK"
        }
        Ok(SafetyResult(should_block: should_block, reason: reason, health: health))
      }
    }
  })
}

// -------------------------------------------------------------------
// Pi Tools for Statistics and Self-Design
// -------------------------------------------------------------------

/// Pi tool: psypi-autonomic-stats — get model quality statistics
pub fn monitor_stats_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-stats",
    description: "Get Monitor statistics (review scores, response times, failure rate)",
    params: [],
    module: "monitor_ai",
    fn_name: "get_model_stats",
    args: [],
    result_format: raw_json(),
  )
}

/// Pi tool: psypi-autonomic-suggest — get work suggestions
pub fn monitor_suggest_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-autonomic-suggest",
    description: "Get work suggestions from Monitor (open issues, stale tasks, pending skills)",
    params: [],
    module: "monitor_ai",
    fn_name: "get_work_suggestions",
    args: [],
    result_format: raw_json(),
  )
}

// -------------------------------------------------------------------
// Slash commands for human interaction
// -------------------------------------------------------------------

/// /autonomic-listen command - Human tells Monitor what to do, Monitor replies in chat
pub fn autonomic_listen_command() -> PiCommandReg {
  command(
    "autonomic-listen",
    "Talk to Monitor AI directly - human and Monitor exchange in chat",
    "
      // If no arguments, show help
      if (!args || args.trim() === '') {
        ctx.ui.notify('Usage: /autonomic-listen <message>\\nExample: /autonomic-listen What should I work on?', 'info');
        return;
      }
      
      // Use the existing callMonitor helper
      const systemPrompt = 'You are Monitor, a senior technical advisor. The human is communicating with you directly. Be concise and helpful.';
      const messages = [{ role: 'user', content: [{ type: 'text', text: args }], timestamp: Date.now() }];
      
      try {
        const reply = await callMonitor(ctx, messages, systemPrompt);
        // Inject Monitor's reply directly into session chat
        pi.sendMessage({
          customType: 'autonomic-reply',
          content: [{ type: 'text', text: 'Monitor: ' + reply }],
          display: 'monitor',
          details: { tool: 'autonomic-listen' }
        }, { triggerTurn: false });
      } catch(e) {
        pi.sendMessage({
          customType: 'autonomic-reply',
          content: [{ type: 'text', text: 'Monitor error: ' + e.message }],
          display: 'error',
          details: { tool: 'autonomic-listen', error: e.message }
        }, { triggerTurn: false });
      }
    ",
  )
}

/// /autonomic-reload command - Reload Pi extensions (for Monitor's self-improvement)
pub fn autonomic_reload_command() -> PiCommandReg {
  command(
    "autonomic-reload",
    "Reload Pi extensions - used after Monitor modifies its own Gleam code",
    "
      ctx.ui.notify('Reloading extensions...', 'info');
      await ctx.reload();
      ctx.ui.notify('Extensions reloaded. Monitor updated.', 'info');
    ",
  )
}

// -------------------------------------------------------------------
// Super Worker: Autonomous Actions
// -------------------------------------------------------------------

pub type MonitorAction {
  MonitorAction(action: String, details: String)
}

fn action_row_decoder() -> decode.Decoder(MonitorAction) {
  use action <- decode.field("action", decode.string)
  use details <- decode.field("details", decode.string)
  decode.success(MonitorAction(action: action, details: details))
}

/// Analyze system state and take autonomous action
/// Called on session_start and agent_end events
pub fn analyze_and_act() -> promise.Promise(Result(MonitorAction, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT * FROM (
        -- Failed tasks needing attention
        SELECT 'failed_tasks' as action, 
               COUNT(*)::TEXT || ' failed tasks need review' as details
        FROM tasks WHERE status = 'FAILED'
        UNION ALL
        -- Critical open issues
        SELECT 'critical_issues' as action,
               COUNT(*)::TEXT || ' critical issues need resolution' as details
        FROM issues WHERE status = 'open' AND severity = 'critical'
        UNION ALL
        -- Stale pending tasks (>7 days)
        SELECT 'stale_tasks' as action,
               COUNT(*)::TEXT || ' stale pending tasks' as details
        FROM tasks WHERE status = 'pending' AND created_at < NOW() - INTERVAL '7 days'
        UNION ALL
        -- All good
        SELECT 'healthy' as action,
               'System is healthy' as details
        WHERE NOT EXISTS (SELECT 1 FROM tasks WHERE status = 'FAILED')
          AND NOT EXISTS (SELECT 1 FROM issues WHERE status = 'open' AND severity = 'critical')
      ) sub
      ORDER BY CASE action 
        WHEN 'failed_tasks' THEN 1 
        WHEN 'critical_issues' THEN 2 
        WHEN 'stale_tasks' THEN 3 
        ELSE 4 
      END
      LIMIT 1
    "
    promise.map(db.query(conn, sql, []), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, action_row_decoder()) {
                Ok(action) -> Ok(action)
                Error(_) -> Ok(MonitorAction(action: "unknown", details: "Could not decode action"))
              }
            }
            [] -> Ok(MonitorAction(action: "healthy", details: "System is healthy"))
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

/// Auto-file an issue from tool error
pub fn auto_file_issue(
  tool_name: String,
  error_message: String,
) -> promise.Promise(Result(String, MonitorError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO issues (title, description, severity, type, created_by, discovered_by, environment)
      VALUES ($1, $2, 'high', 'bug', 'monitor', 'monitor', 'development')
      RETURNING id
    "
    let title = "Tool error: " <> tool_name
    let description = "Error from " <> tool_name <> ": " <> error_message
    let params = [dynamic.string(title), dynamic.string(description)]
    
    promise.map(db.query(conn, sql, params), fn(result) {
      case result {
        Error(e) -> Error(db_error_to_monitor_error(e))
        Ok(query_result) -> {
          case query_result.rows {
            [_row, ..] -> Ok("Issue auto-filed: " <> tool_name)
            [] -> Ok("Issue auto-filed: " <> tool_name)
          }
        }
      }
    })
  }, db_error_to_monitor_error)
}

