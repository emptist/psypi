import gleeunit/should
import gleam/dynamic/decode
import gleam/option.{Some}
import psypi_cli/task.{Pending, Running, Completed, Failed, ConnectionError, QueryError, string_to_status, task_decoder, id_decoder, db_error_to_task_error}
import psypi_cli/db.{ConnectionError as DbConnectionError, QueryError as DbQueryError}
import psypi_cli/task_test_helper

pub fn string_to_status_pending_test() {
  string_to_status("PENDING")
  |> should.equal(Pending)
}

pub fn string_to_status_running_test() {
  string_to_status("RUNNING")
  |> should.equal(Running)
}

pub fn string_to_status_completed_test() {
  string_to_status("COMPLETED")
  |> should.equal(Completed)
}

pub fn string_to_status_failed_test() {
  string_to_status("FAILED")
  |> should.equal(Failed)
}

pub fn string_to_status_default_test() {
  string_to_status("UNKNOWN")
  |> should.equal(Pending)
}

pub fn task_decoder_test() {
  let row = task_test_helper.make_task_row_1()
  
  let assert Ok(decoded) = decode.run(row, task_decoder())
  
  decoded.id
  |> should.equal("task-123")
  
  decoded.title
  |> should.equal("Test Task")
  
  decoded.description
  |> should.equal(Some("A test task"))
  
  decoded.status
  |> should.equal(Pending)
  
  decoded.priority
  |> should.equal(100)
  
  decoded.created_by
  |> should.equal("S-psypi-psypi")
}

pub fn task_decoder_completed_test() {
  let row = task_test_helper.make_task_row_2()
  
  let assert Ok(decoded) = decode.run(row, task_decoder())
  
  decoded.status
  |> should.equal(Completed)
  
  decoded.result
  |> should.equal(Some("Task completed successfully"))
  
  decoded.retry_count
  |> should.equal(1)
}

pub fn id_decoder_test() {
  let row = task_test_helper.make_id_row()

  let assert Ok(id) = decode.run(row, id_decoder())
  id
  |> should.equal("task-789")
}

pub fn db_error_to_task_error_test() {
  let conn_err = db_error_to_task_error(DbConnectionError("Connection failed"))
  conn_err
  |> should.equal(ConnectionError("Connection failed"))

  let query_err = db_error_to_task_error(DbQueryError("Query failed"))
  query_err
  |> should.equal(QueryError("Query failed"))
}
