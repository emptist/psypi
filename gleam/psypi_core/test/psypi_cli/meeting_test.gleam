import gleeunit/should
import psypi_cli/meeting.{Pending, Active, Completed, Cancelled}

pub fn meeting_status_pending_test() {
  let status = Pending
  status
  |> should.equal(Pending)
}

pub fn meeting_status_active_test() {
  let status = Active
  status
  |> should.equal(Active)
}

pub fn meeting_status_completed_test() {
  let status = Completed
  status
  |> should.equal(Completed)
}

pub fn meeting_status_cancelled_test() {
  let status = Cancelled
  status
  |> should.equal(Cancelled)
}

// TODO: Add tests for Meeting decoder if exported
// TODO: Add tests for meeting.list, meeting.create etc. with mocked data
