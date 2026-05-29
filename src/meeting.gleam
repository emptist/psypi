import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import db
import pi_tool_call.{type PiToolCall, PiToolCall, string_param, opt_string_param, from_param, template}

pub type MeetingStatus {
  Active
  Completed
  Cancelled
}

pub type Meeting {
  Meeting(
    id: String,
    topic: String,
    created_by: String,
    status: MeetingStatus,
    created_at: String,
    consensus_at: Option(String),
    consensus: Option(String),
  )
}

pub type Opinion {
  Opinion(
    id: String,
    meeting_id: String,
    author: String,
    perspective: String,
    reasoning: Option(String),
    created_at: String,
  )
}

pub type MeetingError {
  ConnectionError(String)
  QueryError(String)
  NotFound(String)
  DecodeError(String)
}

fn string_to_status(s: String) -> Result(MeetingStatus, String) {
  case s {
    "active" -> Ok(Active)
    "completed" -> Ok(Completed)
    "cancelled" -> Ok(Cancelled)
    _ -> Error("Unknown meeting status: " <> s)
  }
}

fn meeting_decoder() -> decode.Decoder(Meeting) {
  use id <- decode.field("id", decode.string)
  use topic <- decode.field("topic", decode.string)
  use created_by <- decode.field("created_by", decode.string)
  use status_str <- decode.field("status", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use consensus_at <- decode.field("consensus_at", decode.optional(decode.string))
  use consensus <- decode.field("consensus", decode.optional(decode.string))

  case string_to_status(status_str) {
    Error(_) -> decode.failure(Meeting(id: id, topic: topic, created_by: created_by, status: Active, created_at: created_at, consensus_at: consensus_at, consensus: consensus), "Unknown meeting status: " <> status_str)
    Ok(status) -> decode.success(Meeting(
      id: id,
      topic: topic,
      created_by: created_by,
      status: status,
      created_at: created_at,
      consensus_at: consensus_at,
      consensus: consensus,
    ))
  }
}

fn opinion_decoder() -> decode.Decoder(Opinion) {
  use id <- decode.field("id", decode.string)
  use meeting_id <- decode.field("meeting_id", decode.string)
  use author <- decode.field("author", decode.string)
  use perspective <- decode.field("perspective", decode.string)
  use reasoning <- decode.field("reasoning", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)

  decode.success(Opinion(
    id: id,
    meeting_id: meeting_id,
    author: author,
    perspective: perspective,
    reasoning: reasoning,
    created_at: created_at,
  ))
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

fn id_decoder() -> decode.Decoder(String) {
  use id <- decode.field("id", decode.string)
  decode.success(id)
}

fn option_to_dynamic(opt: Option(String)) -> dynamic.Dynamic {
  case opt {
    Some(s) -> dynamic.string(s)
    None -> dynamic.nil()
  }
}

fn db_error_to_meeting_error(e: db.DbError) -> MeetingError {
  case e {
    db.ConnectionError(msg) -> ConnectionError(msg)
    db.QueryError(msg) -> QueryError(msg)
  }
}

pub fn create(
  topic: String,
  created_by: String,
) -> promise.Promise(Result(String, MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO meetings (topic, created_by)
      VALUES ($1, $2)
      RETURNING id
    "
    let params = [dynamic.string(topic), dynamic.string(created_by)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
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
  }, db_error_to_meeting_error)
}

pub fn list(
  status: Option(String),
) -> promise.Promise(Result(List(Meeting), MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = case status {
      Some(_) -> "
        SELECT id::text, topic, created_by, status, created_at::text, consensus_at::text, consensus
        FROM meetings
        WHERE status = $1
        ORDER BY created_at DESC
        LIMIT 100
      "
      None -> "
        SELECT id::text, topic, created_by, status, created_at::text, consensus_at::text, consensus
        FROM meetings
        ORDER BY created_at DESC
        LIMIT 100
      "
    }

    let params = case status {
      Some(s) -> [dynamic.string(s)]
      None -> []
    }

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, meeting_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode meeting row"))
            Ok(meetings) -> Ok(meetings)
          }
        }
      }
    })
  }, db_error_to_meeting_error)
}

pub fn get(
  meeting_id: String,
) -> promise.Promise(Result(Meeting, MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id::text, topic, created_by, status, created_at::text, consensus_at::text, consensus
      FROM meetings
      WHERE id = $1
    "
    let params = [dynamic.string(meeting_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, meeting_decoder()) {
                Ok(meeting) -> Ok(meeting)
                Error(_) -> Error(DecodeError("Failed to decode meeting"))
              }
            }
            _ -> Error(NotFound("Meeting not found"))
          }
        }
      }
    })
  }, db_error_to_meeting_error)
}

pub fn add_opinion(
  meeting_id: String,
  author: String,
  perspective: String,
  reasoning: Option(String),
  position: Option(String),
) -> promise.Promise(Result(String, MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      INSERT INTO meeting_opinions (meeting_id, author, perspective, reasoning, position)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
    "
    let params = [
      dynamic.string(meeting_id),
      dynamic.string(author),
      dynamic.string(perspective),
      option_to_dynamic(reasoning),
      option_to_dynamic(position),
    ]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
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
  }, db_error_to_meeting_error)
}

pub fn list_opinions(
  meeting_id: String,
) -> promise.Promise(Result(List(Opinion), MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      SELECT id::text, meeting_id::text, author, perspective, reasoning, created_at::text
      FROM meeting_opinions
      WHERE meeting_id = $1
      ORDER BY created_at ASC
    "
    let params = [dynamic.string(meeting_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
        Ok(result) -> {
          let decoded = result.rows
            |> list.map(fn(row) { decode.run(row, opinion_decoder()) })
          case decode_all_results(decoded) {
            Error(_) -> Error(DecodeError("Failed to decode opinion row"))
            Ok(opinions) -> Ok(opinions)
          }
        }
      }
    })
  }, db_error_to_meeting_error)
}

pub fn complete(
  meeting_id: String,
  consensus: String,
) -> promise.Promise(Result(String, MeetingError)) {
  db.with_connection(fn(conn) {
    let sql = "
      UPDATE meetings
      SET status = 'completed', consensus_at = NOW(), consensus = $2
      WHERE id = $1
      RETURNING id
    "
    let params = [dynamic.string(meeting_id), dynamic.string(consensus)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
        Ok(result) -> {
          case result.rows {
            [row, ..] -> {
              case decode.run(row, id_decoder()) {
                Ok(id) -> Ok(id)
                Error(_) -> Error(DecodeError("Failed to decode id"))
              }
            }
            _ -> Error(NotFound("Meeting not found"))
          }
        }
      }
    })
  }, db_error_to_meeting_error)
}

// -------------------------------------------------------------------
// Pi Tools
// -------------------------------------------------------------------

/// Pi tool: psypi-meetings — list meetings
pub fn meeting_list_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-meetings",
    description: "List meetings, optionally filtered by status",
    params: [opt_string_param("status")],
    module: "meeting",
    fn_name: "list",
    args: [from_param("params?.status || null")],
    result_format: template("Meetings: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

/// Pi tool: psypi-meeting-get — get a meeting by ID
pub fn meeting_get_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-meeting-get",
    description: "Get a meeting by ID",
    params: [string_param("id")],
    module: "meeting",
    fn_name: "get",
    args: [from_param("params.id || \"\"")],
    result_format: template("Meeting: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

/// Pi tool: psypi-meeting-opinions — list opinions for a meeting
pub fn meeting_opinions_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-meeting-opinions",
    description: "List opinions for a meeting",
    params: [string_param("meeting_id")],
    module: "meeting",
    fn_name: "list_opinions",
    args: [from_param("params.meeting_id || \"\"")],
    result_format: template("Opinions: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

/// Pi tool: psypi-meeting-add — add a meeting
pub fn meeting_create_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-meeting-add",
    description: "Add a new meeting",
    params: [string_param("topic"), opt_string_param("created_by")],
    module: "meeting",
    fn_name: "create",
    args: [from_param("params.topic || \"\""), from_param("params.created_by || \"psypi\"")],
    result_format: template("Meeting created: ${JSON.stringify(gleamValueToJson(r.value))}"),
  )
}

/// Pi tool: psypi-meeting-say — add an opinion to a meeting
pub fn meeting_say_tool() -> PiToolCall {
  PiToolCall(
    name: "psypi-meeting-say",
    description: "Add an opinion to a meeting",
    params: [string_param("meeting_id"), string_param("message")],
    module: "meeting",
    fn_name: "add_opinion",
    args: [
      from_param("params.meeting_id || \"\""),
      from_param("params.author || \"psypi\""),
      from_param("params.message || \"\""),
      from_param("null"),
      from_param("null"),
    ],
    result_format: template("Opinion added: ${r.value}"),
  )
}
