import gleam/dynamic
import gleam/dynamic/decode
import gleam/javascript/promise
import gleam/list
import gleam/option.{type Option, None, Some}
import psypi_cli/db

pub type MeetingStatus {
  Pending
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

fn string_to_status(s: String) -> MeetingStatus {
  case s {
    "active" -> Active
    "completed" -> Completed
    "cancelled" -> Cancelled
    _ -> Pending
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

  decode.success(Meeting(
    id: id,
    topic: topic,
    created_by: created_by,
    status: string_to_status(status_str),
    created_at: created_at,
    consensus_at: consensus_at,
    consensus: consensus,
  ))
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
        SELECT id, topic, created_by, status, created_at::text, consensus_at::text, consensus
        FROM meetings
        WHERE status = $1
        ORDER BY created_at DESC
        LIMIT 100
      "
      None -> "
        SELECT id, topic, created_by, status, created_at::text, consensus_at::text, consensus
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
          let meetings = result.rows
            |> list.map(fn(row) { decode.run(row, meeting_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(meetings)
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
      SELECT id, topic, created_by, status, created_at::text, consensus_at::text, consensus
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
      SELECT id, meeting_id, author, perspective, reasoning, created_at::text
      FROM meeting_opinions
      WHERE meeting_id = $1
      ORDER BY created_at ASC
    "
    let params = [dynamic.string(meeting_id)]

    promise.map(db.query(conn, sql, params), fn(query_result) {
      case query_result {
        Error(e) -> Error(db_error_to_meeting_error(e))
        Ok(result) -> {
          let opinions = result.rows
            |> list.map(fn(row) { decode.run(row, opinion_decoder()) })
            |> list.filter_map(fn(r) { r })

          Ok(opinions)
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
